#!/usr/bin/env bash
set -euo pipefail

# Choose monitors.conf based solely on hostname.
HOSTNAME=${HOSTNAME:-$(uname -n)}

SRC=""
DST="$HOME/.config/hypr/config/monitors.conf"

case "$HOSTNAME" in
  "Wolverine")
    SRC="$HOME/.config/hypr/config/desktop.conf"
    ;;
  "Mentalist")
    SRC="$HOME/.config/hypr/config/laptop.conf"
    ;;
  *)
    # Fallback for unknown hosts
    SRC="$HOME/.config/hypr/config/laptop.conf"
    ;;
esac

echo "[detect-monitors] Hostname: $HOSTNAME"
echo "[detect-monitors] Linking $DST -> $SRC"
ln -sf "$SRC" "$DST"

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload || true
fi