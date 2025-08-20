#!/usr/bin/env bash

# Optimized recording status script with reduced file I/O operations
STATUS_FILE="/tmp/gsr_waybar_status.txt"

# Use parameter expansion for more efficient file reading and conditional logic
# This avoids multiple file operations and variable assignments
if [[ -f "$STATUS_FILE" ]] && ICON=$(<"$STATUS_FILE") && [[ -n "$ICON" ]]; then
    # Output JSON in one operation instead of building string step by step
    printf '{"text": "%s", "tooltip": "Recording in progress...", "class": "recording"}\n' "$ICON"
else
    # Use printf instead of echo for consistent output and better performance
    printf '{}\n'
fi
