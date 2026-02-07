#!/bin/bash

set -euo pipefail

ID_SUFFIX=$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 6)
UNIT_NAME="antigravity-${ID_SUFFIX}"

readonly APP_BIN="/usr/bin/antigravity"
readonly APP_ARGS=(--verbose)

cleanup() {
    echo "[*] Cleaning up scope: $UNIT_NAME"
    systemctl --user kill -s SIGKILL "$UNIT_NAME.scope" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "[*] Launching $UNIT_NAME..."

systemd-run --user \
    --scope \
    --unit="$UNIT_NAME" \
    --property=KillMode=control-group \
    --property=SendSIGKILL=yes \
    --description="Antigravity Electron Wrapper" \
    prlimit --core=0 -- "$APP_BIN" "${APP_ARGS[@]}" || true