#!/usr/bin/env bash

HOSTNAME="$(uname -n)"
CONNECTED="$(hyprctl monitors | grep 'Monitor' | awk '{print $2}')"

case "$HOSTNAME" in
  "Wolverine")
    if echo "$CONNECTED" | grep -q "DP-1"; then
      SRC="$HOME/.config/hypr/config/desktop.conf"
      DST="$HOME/.config/hypr/config/monitors.conf"
      ln -sf "$SRC" "$DST"
    else
      SRC="$HOME/.config/hypr/config/laptop.conf"
      DST="$HOME/.config/hypr/config/monitors.conf"
      ln -sf "$SRC" "$DST"
    fi
    ;;
  "Mentalist")
    if echo "$CONNECTED" | grep -q "HDMI-1"; then
      SRC="$HOME/.config/hypr/config/docked.conf"
      DST="$HOME/.config/hypr/config/monitors.conf"
      ln -sf "$SRC" "$DST"
    else
      SRC="$HOME/.config/hypr/config/laptop.conf"
      DST="$HOME/.config/hypr/config/monitors.conf"
      ln -sf "$SRC" "$DST"
    fi
    ;;
esac

hyprctl reload