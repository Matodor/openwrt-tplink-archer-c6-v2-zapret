#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:?rootfs path required}"
SCRIPT="${2:?init script path required}"

mkdir -p "$ROOT/etc/rc.d"
rm -f "$ROOT"/etc/rc.d/S??zapret "$ROOT"/etc/rc.d/K??zapret

set +e
OUTPUT="$(timeout 5s env IPKG_INSTROOT="$ROOT" bash "$ROOT/etc/rc.common" "$SCRIPT" enable 2>&1)"
STATUS=$?
set -e

printf '%s\n' "$OUTPUT"

if [ "$STATUS" -ne 0 ]; then
    exit "$STATUS"
fi

[ -L "$ROOT/etc/rc.d/S21zapret" ]
