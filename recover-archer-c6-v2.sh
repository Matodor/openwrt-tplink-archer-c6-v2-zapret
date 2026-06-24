#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DEFAULT_PROFILE="tplink-c6-v2"
DEFAULT_TIMEOUT=180
# Use the official factory image by default; custom builds can be selected with --image.
DEFAULT_IMAGE="/home/matodor/openwrt-builds/2026-06-24-openwrt-c6-v2-zapret/artifacts/official-24.10.4/openwrt-24.10.4-ath79-generic-tplink_archer-c6-v2-squashfs-factory.bin"
declare -a DEFAULT_SERVER_IPS_TPLINK_C6_V2=("192.168.0.66/24")
declare -a TPLINK_C6_V2_RECOVERY_NAMES=("ArcherC6v2_tp_recovery.bin" "tp_recovery.bin" "ArcherC6V2_tp_recovery.bin")

IFACE=""
PROFILE="$DEFAULT_PROFILE"
TIMEOUT="$DEFAULT_TIMEOUT"
IMAGE="$DEFAULT_IMAGE"
NO_NM=0
KEEP_LOGS=0
QUIET=0
declare -a SERVER_IPS=()
declare -a LISTEN_IPS=()
declare -a RECOVERY_NAMES=()

RUN_DIR=""
DNSMASQ_LOG=""
TCPDUMP_LOG=""
DNSMASQ_PID=""
TCPDUMP_PID=""
TAIL_PID=""
DNSMASQ_TAIL_PID=""
STATUS="router_silent"
FIRST_EXTERNAL_MAC=""
FIRST_RRQ_FILE=""
FIRST_RRQ_CLIENT_IP=""
HOST_MAC=""
NM_CHANGED=0

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME --iface IFACE [options]

Options:
  --iface IFACE         Host interface to use
  --image PATH          Factory image path
  --server-ip IP/CIDR   Recovery server address to assign; repeatable
  --profile NAME        Device profile; default: $DEFAULT_PROFILE
  --timeout SECONDS     Observation window; default: $DEFAULT_TIMEOUT
  --quiet               Do not stream tcpdump live; keep logs in the run directory
  --no-nm               Do not modify NetworkManager state
  --keep-logs           Keep the run directory after exit
  --help                Show this help

Examples:
  sudo $SCRIPT_NAME --iface enp5s0f3u1u1
  sudo $SCRIPT_NAME --iface enp5s0f3u1u1 --server-ip 192.168.0.66/24
EOF
}

log() {
    printf '[*] %s\n' "$*"
}

warn() {
    printf '[!] %s\n' "$*" >&2
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

join_by() {
    local separator="$1"
    shift
    local first="${1:-}"
    shift || true
    printf '%s' "$first"
    local item
    for item in "$@"; do
        printf '%s%s' "$separator" "$item"
    done
}

cleanup() {
    set +e

    if [[ -n "$TAIL_PID" ]]; then
        kill "$TAIL_PID" 2>/dev/null || true
        wait "$TAIL_PID" 2>/dev/null || true
    fi

    if [[ -n "$DNSMASQ_TAIL_PID" ]]; then
        kill "$DNSMASQ_TAIL_PID" 2>/dev/null || true
        wait "$DNSMASQ_TAIL_PID" 2>/dev/null || true
    fi

    if [[ -n "$TCPDUMP_PID" ]]; then
        kill "$TCPDUMP_PID" 2>/dev/null || true
        wait "$TCPDUMP_PID" 2>/dev/null || true
    fi

    if [[ -n "$DNSMASQ_PID" ]]; then
        kill "$DNSMASQ_PID" 2>/dev/null || true
        wait "$DNSMASQ_PID" 2>/dev/null || true
    fi

    if [[ -n "$IFACE" ]] && ip link show dev "$IFACE" >/dev/null 2>&1; then
        ip -4 addr flush dev "$IFACE" 2>/dev/null || true
    fi

    if [[ $NM_CHANGED -eq 1 ]] && command -v nmcli >/dev/null 2>&1; then
        nmcli device set "$IFACE" managed yes 2>/dev/null || warn "Failed to restore NetworkManager control for $IFACE"
    fi

    if [[ $KEEP_LOGS -eq 0 && -n "$RUN_DIR" && -d "$RUN_DIR" ]]; then
        rm -rf "$RUN_DIR"
    fi
}

trap cleanup EXIT INT TERM

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --iface)
                [[ $# -ge 2 ]] || die "Missing value for --iface"
                IFACE="$2"
                shift 2
                ;;
            --image)
                [[ $# -ge 2 ]] || die "Missing value for --image"
                IMAGE="$2"
                shift 2
                ;;
            --server-ip)
                [[ $# -ge 2 ]] || die "Missing value for --server-ip"
                SERVER_IPS+=("$2")
                shift 2
                ;;
            --profile)
                [[ $# -ge 2 ]] || die "Missing value for --profile"
                PROFILE="$2"
                shift 2
                ;;
            --timeout)
                [[ $# -ge 2 ]] || die "Missing value for --timeout"
                TIMEOUT="$2"
                shift 2
                ;;
            --quiet)
                QUIET=1
                shift
                ;;
            --no-nm)
                NO_NM=1
                shift
                ;;
            --keep-logs)
                KEEP_LOGS=1
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                die "Unknown option: $1"
                ;;
            *)
                if [[ -z "$IFACE" ]]; then
                    IFACE="$1"
                    shift
                else
                    die "Unexpected argument: $1"
                fi
                ;;
        esac
    done
}

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
}

apply_profile_defaults() {
    case "$PROFILE" in
        tplink-c6-v2)
            if [[ ${#SERVER_IPS[@]} -eq 0 ]]; then
                SERVER_IPS=("${DEFAULT_SERVER_IPS_TPLINK_C6_V2[@]}")
            fi
            RECOVERY_NAMES=("${TPLINK_C6_V2_RECOVERY_NAMES[@]}")
            ;;
        *)
            die "Unsupported profile: $PROFILE"
            ;;
    esac
}

build_listen_ips() {
    LISTEN_IPS=()
    local cidr
    for cidr in "${SERVER_IPS[@]}"; do
        LISTEN_IPS+=("${cidr%/*}")
    done
}

validate_server_ips() {
    local listen_ip
    for listen_ip in "${LISTEN_IPS[@]}"; do
        if [[ "$PROFILE" == "tplink-c6-v2" && "$listen_ip" == "192.168.0.86" ]]; then
            die "Do not use 192.168.0.86 as a server IP for tplink-c6-v2; the bootloader uses it as its client IP"
        fi
    done
}

preflight() {
    [[ $EUID -eq 0 ]] || die "Run as root: sudo $SCRIPT_NAME --iface IFACE [options]"
    [[ -n "$IFACE" ]] || die "Missing required --iface"
    [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || die "Timeout must be a positive integer"

    require_cmd ip
    require_cmd tcpdump
    require_cmd dnsmasq

    ip link show dev "$IFACE" >/dev/null 2>&1 || die "Interface not found: $IFACE"
    [[ -f "$IMAGE" ]] || die "Missing factory image: $IMAGE"

    HOST_MAC="$(tr '[:upper:]' '[:lower:]' <"/sys/class/net/$IFACE/address")"
}

print_preflight() {
    local operstate="unknown"
    local carrier="unknown"

    [[ -r "/sys/class/net/$IFACE/operstate" ]] && operstate="$(cat "/sys/class/net/$IFACE/operstate")"
    [[ -r "/sys/class/net/$IFACE/carrier" ]] && carrier="$(cat "/sys/class/net/$IFACE/carrier")"

    log "Interface: $IFACE"
    log "Host MAC: $HOST_MAC"
    log "Operstate: $operstate"
    log "Carrier: $carrier"
    log "Profile: $PROFILE"
    log "Image: $IMAGE"
    log "Server IPs: $(join_by ', ' "${SERVER_IPS[@]}")"

    if command -v ss >/dev/null 2>&1 && ss -lunH | awk '$5 ~ /:69$/ { found=1 } END { exit found ? 0 : 1 }'; then
        warn "UDP port 69 appears busy; another TFTP server may interfere"
    fi

    if command -v nmcli >/dev/null 2>&1; then
        log "NetworkManager: available"
    else
        warn "NetworkManager not found; managed/unmanaged recovery is unavailable"
    fi
}

prepare_run_dir() {
    RUN_DIR="$(mktemp -d /tmp/archer-c6-v2-recovery-XXXXXX)"
    chmod 755 "$RUN_DIR"
    DNSMASQ_LOG="$RUN_DIR/dnsmasq.log"
    TCPDUMP_LOG="$RUN_DIR/tcpdump.log"
}

prepare_recovery_files() {
    local primary="${RECOVERY_NAMES[0]}"
    cp "$IMAGE" "$RUN_DIR/$primary"

    local alias_name
    for alias_name in "${RECOVERY_NAMES[@]:1}"; do
        ln -sf "$primary" "$RUN_DIR/$alias_name"
    done
}

prepare_interface() {
    if [[ $NO_NM -eq 0 ]] && command -v nmcli >/dev/null 2>&1; then
        local managed_state
        managed_state="$(nmcli -g GENERAL.NM-MANAGED device show "$IFACE" 2>/dev/null | tr '[:upper:]' '[:lower:]' | head -n1 || true)"
        if [[ "$managed_state" == "yes" ]]; then
            log "Temporarily disabling NetworkManager control for $IFACE"
            nmcli device set "$IFACE" managed no
            NM_CHANGED=1
        fi
    fi

    ip link set "$IFACE" up
    ip -4 addr flush dev "$IFACE"

    local cidr
    for cidr in "${SERVER_IPS[@]}"; do
        ip addr add "$cidr" dev "$IFACE"
    done
}

start_tcpdump() {
    local capture_filter
    capture_filter="not ether src $HOST_MAC and (arp or (udp and (port 67 or port 68 or port 69)))"

    : >"$TCPDUMP_LOG"
    tcpdump -l -e -n -vvv -i "$IFACE" "$capture_filter" >"$TCPDUMP_LOG" 2>&1 &
    TCPDUMP_PID=$!
    sleep 1
    kill -0 "$TCPDUMP_PID" 2>/dev/null || die "tcpdump failed to start"
}

start_dnsmasq() {
    local listen_csv
    listen_csv="$(join_by ',' "${LISTEN_IPS[@]}")"

    : >"$DNSMASQ_LOG"
    dnsmasq \
        --keep-in-foreground \
        --port=0 \
        --bind-interfaces \
        --interface="$IFACE" \
        --except-interface=lo \
        --listen-address="$listen_csv" \
        --enable-tftp \
        --tftp-root="$RUN_DIR" \
        --log-dhcp \
        --log-queries \
        --log-facility=- \
        >"$DNSMASQ_LOG" 2>&1 &
    DNSMASQ_PID=$!
    sleep 1

    if ! kill -0 "$DNSMASQ_PID" 2>/dev/null; then
        [[ -s "$DNSMASQ_LOG" ]] && cat "$DNSMASQ_LOG" >&2
        die "dnsmasq failed to start"
    fi
}

print_runtime_banner() {
    echo
    echo "Recovery files:"
    ls -l "$RUN_DIR"
    echo
    echo "Interface state:"
    ip -br addr show dev "$IFACE"
    echo
    echo "TFTP recovery environment is ready."
    echo "1. Unplug router power."
    echo "2. Press and hold RESET."
    echo "3. Plug power back in while still holding RESET for 10-15 seconds."
    echo "4. Watch this terminal for ${TIMEOUT}s."
    echo
    if [[ $QUIET -eq 1 ]]; then
        echo "Quiet mode enabled. Packet capture is being written to:"
        echo "$TCPDUMP_LOG"
    else
        echo "Live recovery events:"
        echo "------------------------------------------------------------"
    fi
}

stream_logs() {
    [[ $QUIET -eq 0 ]] || return 0
    tail -n 0 -F "$TCPDUMP_LOG" &
    TAIL_PID=$!
    tail -n 0 -F "$DNSMASQ_LOG" | awk '/dnsmasq-tftp/ { print }' &
    DNSMASQ_TAIL_PID=$!
}

observe() {
    sleep "$TIMEOUT"
    if [[ -n "$TAIL_PID" ]]; then
        kill "$TAIL_PID" 2>/dev/null || true
        wait "$TAIL_PID" 2>/dev/null || true
        TAIL_PID=""
    fi

    if [[ -n "$DNSMASQ_TAIL_PID" ]]; then
        kill "$DNSMASQ_TAIL_PID" 2>/dev/null || true
        wait "$DNSMASQ_TAIL_PID" 2>/dev/null || true
        DNSMASQ_TAIL_PID=""
    fi
}

capture_first_external_mac() {
    FIRST_EXTERNAL_MAC="$(
        awk -v host="$HOST_MAC" '
            /^[0-9]/ {
                src=tolower($2)
                sub(/,$/, "", src)
                if (src ~ /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/ && src != host && src != "ff:ff:ff:ff:ff:ff") {
                    print src
                    exit
                }
            }
        ' "$TCPDUMP_LOG"
    )"
}

capture_first_rrq() {
    local rrq_line
    rrq_line="$(grep -m1 ' RRQ "' "$TCPDUMP_LOG" || true)"
    [[ -z "$rrq_line" ]] && return 0

    FIRST_RRQ_FILE="$(sed -n 's/.* RRQ "\([^"]\+\)".*/\1/p' <<<"$rrq_line")"
    FIRST_RRQ_CLIENT_IP="$(sed -n 's/.* IP \([0-9.]\+\)\.[0-9]\+ > [0-9.]\+\.69:.*/\1/p' <<<"$rrq_line")"
}

classify_status() {
    capture_first_external_mac
    capture_first_rrq

    STATUS="router_silent"

    if [[ -n "$FIRST_EXTERNAL_MAC" ]]; then
        STATUS="bootloader_seen_no_tftp"
    fi

    if [[ -n "$FIRST_RRQ_FILE" || -n "$FIRST_RRQ_CLIENT_IP" ]]; then
        STATUS="tftp_request_seen"
    fi

    if grep -Eq 'sent .+ to ' "$DNSMASQ_LOG"; then
        STATUS="transfer_completed_or_in_progress"
        return
    fi

    if [[ -n "$FIRST_RRQ_CLIENT_IP" ]]; then
        if grep -Fq "$FIRST_RRQ_CLIENT_IP" "$DNSMASQ_LOG"; then
            STATUS="transfer_started"
        fi
    elif [[ -n "$FIRST_RRQ_FILE" ]]; then
        if grep -Fq "$FIRST_RRQ_FILE" "$DNSMASQ_LOG"; then
            STATUS="transfer_started"
        fi
    fi
}

print_hint() {
    case "$STATUS" in
        router_silent)
            echo "Hint: the host was ready, but the router showed no recovery traffic. Recheck port choice (WAN or LAN1), cable link, and the reset timing."
            ;;
        bootloader_seen_no_tftp)
            echo "Hint: the bootloader was visible, but it never sent a TFTP request. Try a different --server-ip set or confirm the recovery button sequence."
            ;;
        tftp_request_seen)
            echo "Hint: a TFTP RRQ was seen. Compare the requested filename with the recovery aliases printed above."
            ;;
        transfer_started)
            echo "Hint: the router asked for the file and dnsmasq reacted. Keep the router powered and inspect $DNSMASQ_LOG if flashing still does not complete."
            ;;
        transfer_completed_or_in_progress)
            echo "Hint: transfer activity was observed. Give the router several minutes before power-cycling it."
            ;;
    esac
}

print_summary() {
    local tftp_result
    tftp_result="$(grep -m1 'dnsmasq-tftp.* sent ' "$DNSMASQ_LOG" || true)"

    echo
    echo "Summary:"
    echo "------------------------------------------------------------"
    echo "STATUS: $STATUS"
    echo "Interface: $IFACE"
    echo "Server IPs: $(join_by ', ' "${SERVER_IPS[@]}")"
    echo "Recovery files: $(join_by ', ' "${RECOVERY_NAMES[@]}")"
    if [[ -n "$FIRST_EXTERNAL_MAC" ]]; then
        echo "First external MAC: $FIRST_EXTERNAL_MAC"
    else
        echo "First external MAC: none"
    fi
    if [[ -n "$FIRST_RRQ_FILE" ]]; then
        echo "Requested filename: $FIRST_RRQ_FILE"
    fi
    if [[ -n "$tftp_result" ]]; then
        echo "TFTP result: $tftp_result"
    fi
    if [[ $KEEP_LOGS -eq 1 ]]; then
        echo "Run directory: $RUN_DIR"
    else
        echo "Run directory: $RUN_DIR (will be removed on exit; rerun with --keep-logs to retain logs)"
    fi
    print_hint
}

main() {
    parse_args "$@"
    apply_profile_defaults
    build_listen_ips
    validate_server_ips
    preflight
    print_preflight
    prepare_run_dir
    prepare_recovery_files
    prepare_interface
    start_tcpdump
    start_dnsmasq
    print_runtime_banner
    stream_logs
    observe
    classify_status
    print_summary
}

main "$@"
