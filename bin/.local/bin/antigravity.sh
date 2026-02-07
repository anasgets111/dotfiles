#!/bin/bash

set -euo pipefail

UNIT_NAME="antigravity-$(date +%s)"
readonly APP_BIN="/usr/bin/antigravity"
readonly APP_ARGS=(--verbose)

cleanup() {
    echo "[*] Cleaning up scope..."
    systemctl --user kill -s SIGKILL "$UNIT_NAME.scope" 2>/dev/null || true
}
trap cleanup EXIT

echo "[*] Launching $UNIT_NAME..."

systemd-run --user \
    --scope \
    --unit="$UNIT_NAME" \
    --property=LimitCORE=0 \
    --property=KillMode=control-group \
    --property=SendSIGKILL=yes \
    --description="Antigravity Electron Wrapper" \
    "$APP_BIN" "${APP_ARGS[@]}" || true

# trap EXIT handles cleanup automatically
