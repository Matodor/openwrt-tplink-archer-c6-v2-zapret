#!/usr/bin/env bash
set -euo pipefail

IB_DIR="/tmp/openwrt-imagebuilder-2026-06-24-c6v2/openwrt-imagebuilder-25.12.4-ath79-generic.Linux-x86_64"
PKG_FILE="${1:?package file path required}"
MANIFEST_FILE="${2:?manifest output path required}"
OUT_BIN="${3:?output directory required}"
PKG_STRING="$(tr '\n' ' ' < "$PKG_FILE")"
FILES_DIR="$(dirname "$0")/files"

rm -rf "$OUT_BIN"
mkdir -p "$OUT_BIN"

cd "$IB_DIR"
make clean
make manifest PROFILE="tplink_archer-c6-v2" PACKAGES="$PKG_STRING" > "$MANIFEST_FILE"
if [ -d "$FILES_DIR" ]; then
    make image PROFILE="tplink_archer-c6-v2" PACKAGES="$PKG_STRING" BIN_DIR="$OUT_BIN" FILES="$FILES_DIR"
else
    make image PROFILE="tplink_archer-c6-v2" PACKAGES="$PKG_STRING" BIN_DIR="$OUT_BIN"
fi
