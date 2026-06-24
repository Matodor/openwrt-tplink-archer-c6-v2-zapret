#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TOOL="$ROOT_DIR/files/usr/bin/zapret-tool"
INIT="$ROOT_DIR/files/etc/init.d/zapret-tool"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

assert_contains() {
	file="$1"
	needle="$2"
	grep -F -- "$needle" "$file" >/dev/null || fail "expected '$needle' in $file"
}

assert_not_contains() {
	file="$1"
	needle="$2"
	if grep -F -- "$needle" "$file" >/dev/null; then
		fail "did not expect '$needle' in $file"
	fi
}

make_env() {
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/ipset" "$tmp/fake" "$tmp/tmp" "$tmp/flowseal-src/lists" "$tmp/flowseal-src/.service" "$tmp/flowseal-src/bin" "$tmp/flowseal-src/utils"

	cat > "$tmp/zapret.conf" <<'EOF'
config main 'config'
	option run_on_boot '1'
	option MODE_FILTER 'autohostlist'
	option NFQWS_PORTS_TCP '80,443,2053,2083,2087,2096,8443'
	option NFQWS_PORTS_UDP '443,19294-19344,50000-50100'
	option NFQWS_OPT '
--comment=original
--filter-tcp=443 <HOSTLIST>
--dpi-desync=split2
'
EOF

	: > "$tmp/ipset/zapret-hosts-auto.txt"
	: > "$tmp/ipset/zapret-hosts-user.txt"
	: > "$tmp/ipset/zapret-hosts-user-exclude.txt"
	: > "$tmp/ipset/zapret-hosts-google.txt"
	: > "$tmp/fake/stun.bin"
	: > "$tmp/fake/tls_clienthello_www_google_com.bin"
	: > "$tmp/fake/tls_clienthello_vk_com.bin"
	: > "$tmp/fake/tls_clienthello_gosuslugi_ru.bin"
	: > "$tmp/fake/t2.bin"
	: > "$tmp/fake/4pda.bin"
	: > "$tmp/fake/quic_initial_www_google_com.bin"
	: > "$tmp/hosts"

	cat > "$tmp/flowseal-src/lists/list-general.txt" <<'EOF'
discord.com
discord.gg
cloudflare-ech.com
EOF
	cat > "$tmp/flowseal-src/lists/list-google.txt" <<'EOF'
youtube.com
googlevideo.com
ytimg.com
EOF
	cat > "$tmp/flowseal-src/lists/list-exclude.txt" <<'EOF'
yandex.ru
sberbank.ru
steamcommunity.com
EOF
	cat > "$tmp/flowseal-src/.service/hosts" <<'EOF'
149.154.167.220 web.telegram.org
149.154.167.220 api.telegram.org
149.154.167.220 t.me
104.25.158.178 finland10000.discord.media
104.25.158.178 finland10001.discord.media
EOF
	cat > "$tmp/flowseal-src/.service/ipset-service.txt" <<'EOF'
1.1.1.0/24
8.8.8.8/32
EOF
	cat > "$tmp/flowseal-src/bin/quic_initial_dbankcloud_ru.bin" <<'EOF'
fake-dbankcloud
EOF
	cat > "$tmp/flowseal-src/utils/targets.txt" <<'EOF'
DiscordMain = "https://discord.com"
YouTubeWeb = "https://www.youtube.com"
CloudflareDNS1111 = "PING:1.1.1.1"
EOF

	echo "$tmp"
}

run_tool() {
	tmp="$1"
	shift
	ZTOOL_CONF="$tmp/zapret.conf" \
	ZTOOL_BACKUP="$tmp/zapret.conf.ztool.bak" \
	ZTOOL_IPSET_DIR="$tmp/ipset" \
	ZTOOL_FAKE_DIR="$tmp/fake" \
	ZTOOL_TMP_DIR="$tmp/tmp" \
	ZTOOL_HOSTS_FILE="$tmp/hosts" \
	ZTOOL_FLOWSEAL_BASE="file://$tmp/flowseal-src" \
	ZTOOL_TEST_RESULT_FILE="$tmp/test-results.txt" \
	ZTOOL_NO_RESTART=1 \
	ZTOOL_NO_UCI=1 \
	sh "$TOOL" "$@"
}

run_tool_with_path() {
	tmp="$1"
	path_prefix="$2"
	shift 2
	ZTOOL_CONF="$tmp/zapret.conf" \
	ZTOOL_BACKUP="$tmp/zapret.conf.ztool.bak" \
	ZTOOL_IPSET_DIR="$tmp/ipset" \
	ZTOOL_FAKE_DIR="$tmp/fake" \
	ZTOOL_TMP_DIR="$tmp/tmp" \
	ZTOOL_HOSTS_FILE="$tmp/hosts" \
	ZTOOL_FLOWSEAL_BASE="file://$tmp/flowseal-src" \
	ZTOOL_TEST_RESULT_FILE="$tmp/test-results.txt" \
	ZTOOL_NO_RESTART=1 \
	ZTOOL_NO_UCI=1 \
	PATH="$path_prefix:$PATH" \
	sh "$TOOL" "$@"
}

run_tool_with_input() {
	tmp="$1"
	input="$2"
	shift 2
	printf '%b' "$input" | ZTOOL_CONF="$tmp/zapret.conf" \
	ZTOOL_BACKUP="$tmp/zapret.conf.ztool.bak" \
	ZTOOL_IPSET_DIR="$tmp/ipset" \
	ZTOOL_FAKE_DIR="$tmp/fake" \
	ZTOOL_TMP_DIR="$tmp/tmp" \
	ZTOOL_HOSTS_FILE="$tmp/hosts" \
	ZTOOL_FLOWSEAL_BASE="file://$tmp/flowseal-src" \
	ZTOOL_TEST_RESULT_FILE="$tmp/test-results.txt" \
	ZTOOL_NO_RESTART=1 \
	ZTOOL_NO_UCI=1 \
	sh "$TOOL" "$@"
}

run_tool_with_restart() {
	tmp="$1"
	shift
	ZTOOL_CONF="$tmp/zapret.conf" \
	ZTOOL_BACKUP="$tmp/zapret.conf.ztool.bak" \
	ZTOOL_IPSET_DIR="$tmp/ipset" \
	ZTOOL_FAKE_DIR="$tmp/fake" \
	ZTOOL_TMP_DIR="$tmp/tmp" \
	ZTOOL_HOSTS_FILE="$tmp/hosts" \
	ZTOOL_FLOWSEAL_BASE="file://$tmp/flowseal-src" \
	ZTOOL_TEST_RESULT_FILE="$tmp/test-results.txt" \
	ZTOOL_INIT="$tmp/init-zapret" \
	ZTOOL_SYNC_CONFIG="$tmp/sync-config" \
	ZTOOL_NO_UCI=1 \
	sh "$TOOL" "$@"
}

test_backup_restore_roundtrip() {
	tmp="$(make_env)"
	cp "$tmp/zapret.conf" "$tmp/original.conf"

	run_tool "$tmp" backup >/dev/null
	run_tool "$tmp" apply v6 >/dev/null
	assert_contains "$tmp/zapret.conf" "--comment=ZTOOL_v6"
	run_tool "$tmp" restore >/dev/null

	cmp "$tmp/original.conf" "$tmp/zapret.conf" >/dev/null || fail "restore did not return original config"
	rm -rf "$tmp"
}

test_apply_v6_keeps_discord_blocks() {
	tmp="$(make_env)"

	run_tool "$tmp" apply v6 >/dev/null

	assert_contains "$tmp/zapret.conf" "--comment=ZTOOL_v6"
	assert_contains "$tmp/zapret.conf" "--hostlist=$tmp/ipset/zapret-hosts-google.txt"
	assert_contains "$tmp/zapret.conf" "--filter-udp=19294-19344,50000-50100"
	assert_contains "$tmp/zapret.conf" "--hostlist-domains=discord.media"
	rm -rf "$tmp"
}

test_apply_youtube_adds_default_tail() {
	tmp="$(make_env)"

	run_tool "$tmp" apply yv03 >/dev/null

	assert_contains "$tmp/zapret.conf" "--comment=ZTOOL_yv03"
	assert_contains "$tmp/zapret.conf" "--hostlist=$tmp/ipset/zapret-hosts-google.txt"
	assert_contains "$tmp/zapret.conf" "--filter-tcp=443 <HOSTLIST>"
	assert_contains "$tmp/zapret.conf" "--filter-udp=19294-19344,50000-50100"
	rm -rf "$tmp"
}

test_autohost_toggle_and_clear() {
	tmp="$(make_env)"
	printf '%s\n' blocked.example > "$tmp/ipset/zapret-hosts-auto.txt"

	run_tool "$tmp" autohost off >/dev/null
	assert_contains "$tmp/zapret.conf" "option MODE_FILTER 'hostlist'"

	run_tool "$tmp" autohost on >/dev/null
	assert_contains "$tmp/zapret.conf" "option MODE_FILTER 'autohostlist'"

	run_tool "$tmp" autohost clear >/dev/null
	[ ! -s "$tmp/ipset/zapret-hosts-auto.txt" ] || fail "autohost clear did not empty file"
	rm -rf "$tmp"
}

test_domains_add_list_delete() {
	tmp="$(make_env)"

	run_tool "$tmp" domains add https://Example.COM/some/path >/dev/null
	run_tool "$tmp" domains add example.com >/dev/null
	run_tool "$tmp" domains list > "$tmp/domains.out"

	assert_contains "$tmp/domains.out" "example.com"
	[ "$(grep -c '^example\.com$' "$tmp/ipset/zapret-hosts-user.txt")" = "1" ] || fail "domain was duplicated"

	run_tool "$tmp" domains del example.com >/dev/null
	assert_not_contains "$tmp/ipset/zapret-hosts-user.txt" "example.com"
	rm -rf "$tmp"
}

test_current_smoke_failure_is_nonfatal() {
	tmp="$(make_env)"
	mkdir -p "$tmp/bin"
	cat > "$tmp/bin/curl" <<'EOF'
#!/bin/sh
exit 28
EOF
	chmod 755 "$tmp/bin/curl"

	run_tool_with_path "$tmp" "$tmp/bin" test current > "$tmp/test-current.out"

	assert_contains "$tmp/test-current.out" "Result: 0/6"
	assert_contains "$tmp/test-current.out" "router-local smoke test"
	rm -rf "$tmp"
}

test_flowseal_test_treats_http_error_pages_as_reachable() {
	tmp="$(make_env)"
	run_tool "$tmp" flowseal update >/dev/null
	cat > "$tmp/tmp/zapret-flowseal/targets.txt" <<'EOF'
# Example = "https://example.invalid"
DiscordGateway = "https://gateway.discord.gg"
YouTubeImage = "https://i.ytimg.com"
EOF
	mkdir -p "$tmp/bin"
	cat > "$tmp/bin/curl" <<'EOF'
#!/bin/sh
for arg in "$@"; do
	case "$arg" in
	-*f*) exit 22 ;;
	esac
done
exit 0
EOF
	chmod 755 "$tmp/bin/curl"

	run_tool_with_path "$tmp" "$tmp/bin" flowseal test > "$tmp/flowseal-test.out"

	assert_not_contains "$tmp/flowseal-test.out" "#KeyName"
	assert_contains "$tmp/flowseal-test.out" "[ OK ] DiscordGateway"
	assert_contains "$tmp/flowseal-test.out" "[ OK ] YouTubeImage"
	rm -rf "$tmp"
}

test_flowseal_update_writes_lists_and_tmp_ipset() {
	tmp="$(make_env)"

	run_tool "$tmp" flowseal update >/dev/null
	run_tool "$tmp" flowseal ipset update >/dev/null

	assert_contains "$tmp/ipset/flowseal-general.txt" "discord.com"
	assert_contains "$tmp/ipset/flowseal-google.txt" "googlevideo.com"
	assert_contains "$tmp/ipset/flowseal-exclude.txt" "sberbank.ru"
	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "web.telegram.org"
	assert_contains "$tmp/ipset/zapret-hosts-discord-media.txt" "finland10000.discord.media"
	assert_contains "$tmp/fake/quic_initial_dbankcloud_ru.bin" "fake-dbankcloud"
	assert_contains "$tmp/tmp/zapret-flowseal/ipset-service.txt" "1.1.1.0/24"
	[ ! -f "$tmp/ipset/ipset-service.txt" ] || fail "flowseal ipset was written to flash ipset dir"
	rm -rf "$tmp"
}

test_flowseal_update_seeds_compact_telegram_domains() {
	tmp="$(make_env)"

	run_tool "$tmp" flowseal update >/dev/null

	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "telegram.org"
	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "telegra.ph"
	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "fragment.com"
	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "telegram-cdn.org"
	rm -rf "$tmp"
}

test_flowseal_migrate_user_moves_telegram_only() {
	tmp="$(make_env)"
	cat > "$tmp/ipset/zapret-hosts-user.txt" <<'EOF'
discord.com
web.telegram.org
api.telegram.org
example.org
t.me
EOF

	run_tool "$tmp" flowseal migrate-user >/dev/null

	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "web.telegram.org"
	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "api.telegram.org"
	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "t.me"
	assert_contains "$tmp/ipset/zapret-hosts-user.txt" "discord.com"
	assert_contains "$tmp/ipset/zapret-hosts-user.txt" "example.org"
	assert_not_contains "$tmp/ipset/zapret-hosts-user.txt" "web.telegram.org"
	[ -f "$tmp/ipset/zapret-hosts-user.txt.ztool.bak" ] || fail "migration backup was not created"
	rm -rf "$tmp"
}

test_flowseal_migrate_user_moves_compact_telegram_aliases() {
	tmp="$(make_env)"
	cat > "$tmp/ipset/zapret-hosts-user.txt" <<'EOF'
telegra.ph
fragment.com
telegram-cdn.org
tx.me
example.org
EOF

	run_tool "$tmp" flowseal migrate-user >/dev/null

	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "telegra.ph"
	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "fragment.com"
	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "telegram-cdn.org"
	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "tx.me"
	assert_contains "$tmp/ipset/zapret-hosts-user.txt" "example.org"
	assert_not_contains "$tmp/ipset/zapret-hosts-user.txt" "telegra.ph"
	rm -rf "$tmp"
}

test_flowseal_update_preserves_existing_telegram_list() {
	tmp="$(make_env)"
	printf '%s\n' custom.telegram.org > "$tmp/ipset/zapret-hosts-telegram.txt"

	run_tool "$tmp" flowseal update >/dev/null

	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "custom.telegram.org"
	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "web.telegram.org"
	rm -rf "$tmp"
}

test_flowseal_telegram_reset_replaces_corrupted_list() {
	tmp="$(make_env)"
	run_tool "$tmp" flowseal update >/dev/null
	cat > "$tmp/ipset/zapret-hosts-telegram.txt" <<'EOF'
ablse.telegram.org
awi-docs.telegram.org
telegram.clold
EOF

	run_tool "$tmp" flowseal telegram-reset >/dev/null

	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "telegram.org"
	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "web.telegram.org"
	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "telegra.ph"
	assert_not_contains "$tmp/ipset/zapret-hosts-telegram.txt" "ablse.telegram.org"
	assert_not_contains "$tmp/ipset/zapret-hosts-telegram.txt" "telegram.clold"
	[ -f "$tmp/ipset/zapret-hosts-telegram.txt.ztool-reset.bak" ] || fail "telegram reset backup was not created"
	rm -rf "$tmp"
}

test_apply_flowseal_general_uses_flowseal_lists() {
	tmp="$(make_env)"
	run_tool "$tmp" flowseal update >/dev/null

	run_tool "$tmp" flowseal apply fs-general >/dev/null

	assert_contains "$tmp/zapret.conf" "--comment=ZTOOL_fs-general"
	assert_contains "$tmp/zapret.conf" "--hostlist=$tmp/ipset/flowseal-general.txt"
	assert_contains "$tmp/zapret.conf" "--hostlist=$tmp/ipset/flowseal-google.txt"
	assert_contains "$tmp/zapret.conf" "--hostlist=$tmp/ipset/zapret-hosts-telegram.txt"
	assert_contains "$tmp/zapret.conf" "--dpi-desync-fake-discord=$tmp/fake/quic_initial_dbankcloud_ru.bin"
	rm -rf "$tmp"
}

test_apply_flowseal_simple_fake_is_known_strategy() {
	tmp="$(make_env)"
	run_tool "$tmp" flowseal update >/dev/null

	run_tool "$tmp" flowseal apply FS-SIMPLE-FAKE >/dev/null

	assert_contains "$tmp/zapret.conf" "--comment=ZTOOL_fs-simple-fake"
	assert_contains "$tmp/zapret.conf" "--dpi-desync=fake"
	rm -rf "$tmp"
}

test_apply_flowseal_extended_variants_are_known() {
	tmp="$(make_env)"
	run_tool "$tmp" flowseal update >/dev/null
	names="fs-alt01 fs-alt02 fs-alt03 fs-alt04 fs-alt05 fs-alt06 fs-alt07 fs-alt08 fs-alt09 fs-alt10 fs-alt11 fs-alt12 fs-simple-fake-alt01 fs-simple-fake-alt02 fs-fake-tls-auto-alt01 fs-fake-tls-auto-alt02 fs-fake-tls-auto-alt03"

	for name in $names; do
		run_tool "$tmp" flowseal apply "$name" >/dev/null
		assert_contains "$tmp/zapret.conf" "--comment=ZTOOL_$name"
	done

	run_tool "$tmp" flowseal apply fs-alt12 >/dev/null
	assert_contains "$tmp/zapret.conf" "--dpi-desync-hostfakesplit-mod=host=www.google.com"
	assert_contains "$tmp/zapret.conf" "--dpi-desync-fake-discord=$tmp/fake/stun.bin"
	rm -rf "$tmp"
}

test_flowseal_udp_block_includes_google_hosts_for_youtube_quic() {
	tmp="$(make_env)"
	run_tool "$tmp" flowseal update >/dev/null

	run_tool "$tmp" flowseal apply fs-fake-tls-auto-alt03 >/dev/null
	awk '/^--new$/ {exit} {print}' "$tmp/zapret.conf" > "$tmp/first-block.out"

	assert_contains "$tmp/first-block.out" "--filter-udp=443"
	assert_contains "$tmp/first-block.out" "--hostlist=$tmp/ipset/flowseal-google.txt"
	assert_contains "$tmp/first-block.out" "--hostlist=$tmp/ipset/zapret-hosts-google.txt"
	rm -rf "$tmp"
}

test_restart_syncs_runtime_config_before_service_restart() {
	tmp="$(make_env)"
	cat > "$tmp/sync-config" <<'EOF'
#!/bin/sh
echo sync >> "$ZTOOL_RESTART_LOG"
EOF
	cat > "$tmp/init-zapret" <<'EOF'
#!/bin/sh
echo "$1" >> "$ZTOOL_RESTART_LOG"
EOF
	chmod 755 "$tmp/sync-config" "$tmp/init-zapret"

	ZTOOL_RESTART_LOG="$tmp/restart.log" run_tool_with_restart "$tmp" flowseal update >/dev/null

	sed -n '1,2p' "$tmp/restart.log" > "$tmp/restart-first-two.log"
	cat > "$tmp/restart-expected.log" <<'EOF'
sync
restart
EOF
	cmp "$tmp/restart-expected.log" "$tmp/restart-first-two.log" >/dev/null || fail "runtime sync did not run before restart"
	rm -rf "$tmp"
}

test_flowseal_hosts_install_remove_marker_block() {
	tmp="$(make_env)"
	run_tool "$tmp" flowseal update >/dev/null

	run_tool "$tmp" flowseal hosts install >/dev/null
	assert_contains "$tmp/hosts" "ZTOOL-FLOWSEAL-BEGIN"
	assert_contains "$tmp/hosts" "web.telegram.org"

	run_tool "$tmp" flowseal hosts remove >/dev/null
	assert_not_contains "$tmp/hosts" "ZTOOL-FLOWSEAL-BEGIN"
	assert_not_contains "$tmp/hosts" "web.telegram.org"
	rm -rf "$tmp"
}

test_flowseal_boot_update_refreshes_persistent_and_tmp_lists() {
	tmp="$(make_env)"

	run_tool "$tmp" flowseal boot-update >/dev/null

	assert_contains "$tmp/ipset/flowseal-general.txt" "discord.com"
	assert_contains "$tmp/ipset/zapret-hosts-telegram.txt" "api.telegram.org"
	assert_contains "$tmp/tmp/zapret-flowseal/ipset-service.txt" "8.8.8.8/32"
	rm -rf "$tmp"
}

test_flowseal_update_uses_ipv4_curl() {
	tmp="$(make_env)"
	mkdir -p "$tmp/bin"
	cat > "$tmp/bin/curl" <<'EOF'
#!/bin/sh
echo "$*" >> "$ZTOOL_CURL_LOG"
url=""
out=""
while [ "$#" -gt 0 ]; do
	case "$1" in
	-o)
		shift
		out="$1"
		;;
	file://*)
		url="$1"
		;;
	esac
	shift
done
[ -n "$url" ] || exit 2
[ -n "$out" ] || exit 2
cp "${url#file://}" "$out"
EOF
	chmod 755 "$tmp/bin/curl"

	ZTOOL_CURL_LOG="$tmp/curl.log" run_tool_with_path "$tmp" "$tmp/bin" flowseal update >/dev/null

	assert_contains "$tmp/curl.log" "-4"
	rm -rf "$tmp"
}

test_flowseal_update_retries_downloads() {
	tmp="$(make_env)"
	mkdir -p "$tmp/bin"
	cat > "$tmp/bin/curl" <<'EOF'
#!/bin/sh
count=0
[ -f "$ZTOOL_CURL_COUNT" ] && count="$(cat "$ZTOOL_CURL_COUNT")"
count=$((count + 1))
echo "$count" > "$ZTOOL_CURL_COUNT"
if [ "$count" = "1" ]; then
	exit 28
fi
url=""
out=""
while [ "$#" -gt 0 ]; do
	case "$1" in
	-o)
		shift
		out="$1"
		;;
	file://*)
		url="$1"
		;;
	esac
	shift
done
cp "${url#file://}" "$out"
EOF
	chmod 755 "$tmp/bin/curl"

	ZTOOL_CURL_COUNT="$tmp/curl.count" ZTOOL_DOWNLOAD_SLEEP=0 run_tool_with_path "$tmp" "$tmp/bin" flowseal update >/dev/null

	assert_contains "$tmp/ipset/flowseal-general.txt" "discord.com"
	[ "$(cat "$tmp/curl.count")" -gt 1 ] || fail "curl retry was not exercised"
	rm -rf "$tmp"
}

test_flowseal_auto_selects_best_and_saves_after_confirmation() {
	tmp="$(make_env)"
	run_tool "$tmp" flowseal update >/dev/null
	cat > "$tmp/test-results.txt" <<'EOF'
fs-general 1 3
fs-alt 2 3
fs-simple-fake 3 3
fs-fake-tls-auto 0 3
fs-general-ipset 2 3
EOF

	run_tool_with_input "$tmp" "y\n" flowseal auto > "$tmp/auto.out"

	assert_contains "$tmp/auto.out" "Best strategy: fs-simple-fake 3/3"
	assert_contains "$tmp/zapret.conf" "--comment=ZTOOL_fs-simple-fake"
	rm -rf "$tmp"
}

test_flowseal_auto_considers_extended_variants() {
	tmp="$(make_env)"
	run_tool "$tmp" flowseal update >/dev/null
	cat > "$tmp/test-results.txt" <<'EOF'
fs-general 1 5
fs-alt01 2 5
fs-alt12 5 5
fs-simple-fake 3 5
fs-fake-tls-auto-alt03 4 5
EOF

	run_tool_with_input "$tmp" "y\n" flowseal auto > "$tmp/auto.out"

	assert_contains "$tmp/auto.out" "Best strategy: fs-alt12 5/5"
	assert_contains "$tmp/zapret.conf" "--comment=ZTOOL_fs-alt12"
	rm -rf "$tmp"
}

test_flowseal_auto_restores_original_without_confirmation() {
	tmp="$(make_env)"
	cp "$tmp/zapret.conf" "$tmp/original.conf"
	run_tool "$tmp" flowseal update >/dev/null
	cat > "$tmp/test-results.txt" <<'EOF'
fs-general 1 3
fs-alt 2 3
fs-simple-fake 3 3
fs-fake-tls-auto 0 3
fs-general-ipset 2 3
EOF

	run_tool_with_input "$tmp" "n\n" flowseal auto > "$tmp/auto.out"

	assert_contains "$tmp/auto.out" "Restored original config"
	cmp "$tmp/original.conf" "$tmp/zapret.conf" >/dev/null || fail "auto mode did not restore original config"
	rm -rf "$tmp"
}

test_init_script_runs_boot_update() {
	[ -f "$INIT" ] || fail "init script missing: $INIT"
	assert_contains "$INIT" "START=99"
	assert_contains "$INIT" "zapret-tool flowseal boot-update"
}

test_backup_restore_roundtrip
test_apply_v6_keeps_discord_blocks
test_apply_youtube_adds_default_tail
test_autohost_toggle_and_clear
test_domains_add_list_delete
test_current_smoke_failure_is_nonfatal
test_flowseal_test_treats_http_error_pages_as_reachable
test_flowseal_update_writes_lists_and_tmp_ipset
test_flowseal_update_seeds_compact_telegram_domains
test_flowseal_migrate_user_moves_telegram_only
test_flowseal_migrate_user_moves_compact_telegram_aliases
test_flowseal_update_preserves_existing_telegram_list
test_flowseal_telegram_reset_replaces_corrupted_list
test_apply_flowseal_general_uses_flowseal_lists
test_apply_flowseal_simple_fake_is_known_strategy
test_flowseal_hosts_install_remove_marker_block
test_flowseal_udp_block_includes_google_hosts_for_youtube_quic
test_restart_syncs_runtime_config_before_service_restart
test_flowseal_boot_update_refreshes_persistent_and_tmp_lists
test_flowseal_update_uses_ipv4_curl
test_flowseal_update_retries_downloads
test_flowseal_auto_selects_best_and_saves_after_confirmation
test_flowseal_auto_considers_extended_variants
test_flowseal_auto_restores_original_without_confirmation
test_apply_flowseal_extended_variants_are_known
test_init_script_runs_boot_update

echo "zapret-tool tests passed"
