#!/usr/bin/env bash

STATUS_FILE="/tmp/gsr_waybar_status.txt"
ICON=""

if [ -f "$STATUS_FILE" ]; then
    ICON=$(cat "$STATUS_FILE")
fi

if [ -n "$ICON" ]; then
    # If ICON is not empty, show it.
    # You can add a class for styling, e.g., "recording"
    echo "{\"text\": \"$ICON\", \"tooltip\": \"Recording in progress...\", \"class\": \"recording\"}"
else
    # If ICON is empty, output nothing (or an empty JSON object to hide the module)
    echo "{}"
    # Alternatively, to show nothing and ensure the module collapses:
    # echo "{\"text\": \"\"}"
fi
