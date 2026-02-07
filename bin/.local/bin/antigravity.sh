#!/bin/bash

set -u

UNIT_NAME="antigravity-$(date +%s)"
readonly UNIT_NAME
readonly TRIGGER="Lifecycle#onWillShutdown - end 'antigravityAnalytics'"
readonly APP_BIN="/usr/bin/antigravity"
readonly APP_ARGS=(--verbose)
readonly LOG_TIMEOUT_SECONDS="${LOG_TIMEOUT_SECONDS:-180}"

kill_scope() {
    systemctl --user kill --signal=SIGKILL "${UNIT_NAME}.scope" >/dev/null 2>&1 || true
}

trap kill_scope EXIT INT TERM

echo "[*] Start as: $UNIT_NAME"

systemd-run --user \
    --scope \
    --unit="$UNIT_NAME" \
    --property=KillMode=control-group \
    --property=LimitCORE=0 \
    /bin/bash -c \
    'exec prlimit --core=0 "$1" "${@:2}" 2>&1 | systemd-cat --identifier="$0"' \
    "$UNIT_NAME" "$APP_BIN" "${APP_ARGS[@]}" &

if command -v timeout >/dev/null 2>&1 && [[ "$LOG_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] && (( LOG_TIMEOUT_SECONDS > 0 )); then
    timeout "${LOG_TIMEOUT_SECONDS}s" journalctl --user --identifier="$UNIT_NAME" --follow --output=cat | \
        grep --line-buffered --fixed-strings --max-count=1 "$TRIGGER" >/dev/null || true
else
    journalctl --user --identifier="$UNIT_NAME" --follow --output=cat | \
        grep --line-buffered --fixed-strings --max-count=1 "$TRIGGER" >/dev/null || true
fi

kill_scope
trap - EXIT INT TERM

echo "[*] Remaining processes are killed."
