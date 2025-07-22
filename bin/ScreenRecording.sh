#!/bin/bash

# --- User Configurable Variables ---
VIDEO_DIR="$HOME/Videos" # Directory for recordings
TARGET_MONITOR="eDP-1"               # Monitor to record (e.g., DP-3, eDP-1, or use 'focused' for active monitor)
AUDIO_SOURCE=""       # leave empty "" for no audio, or "default_output" for system audio or "default_output|default_input" for both
CONTAINER_FORMAT="mp4"              # Video container format (mp4, mkv, etc.)
WAYBAR_ICON=" "                     # Icon to show in Waybar when recording (ensure font supports it)

# SDR Recording Settings
SDR_FPS="60"
SDR_CODEC="h264"
SDR_COLOR_RANGE="limited"

# HDR Recording Settings
HDR_FPS="60"                        # Can be different from SDR_FPS if desired, e.g., 120
HDR_CODEC="hevc_hdr"
HDR_COLOR_RANGE="full"
HDR_MONITOR_FORMAT_INDICATOR="XBGR2101010" # The 'currentFormat' string from hyprctl that indicates HDR

# --- Script Internals (Less likely to change) ---
PID_FILE="/tmp/gsr_video_recording.pid"
LOG_FILE="/tmp/gsr_video_recording.log"
STATUS_FILE="/tmp/gsr_waybar_status.txt"
FILENAME_STORE_FILE="/tmp/gsr_video_filename.txt"

# --- Script Logic ---

# Ensure output directory exists
mkdir -p "$VIDEO_DIR"

if [ -f "$PID_FILE" ]; then
    # PID file exists, so recording is presumed to be running
    echo "Stop signal sent to gpu-screen-recorder (PID: $(cat "$PID_FILE"))." >> "$LOG_FILE"
    pkill --signal SIGINT -F "$PID_FILE"
    rm "$PID_FILE"
    echo "" > "$STATUS_FILE" # Clear status for Waybar

    RECORDED_FILENAME=""
    if [ -f "$FILENAME_STORE_FILE" ]; then
        RECORDED_FILENAME=$(cat "$FILENAME_STORE_FILE")
        rm "$FILENAME_STORE_FILE"
    fi

    if [ -n "$RECORDED_FILENAME" ]; then
        notify-send -i video-x-generic "gpu-screen-recorder" "Video recording STOPPED\nSaved to: $RECORDED_FILENAME"
    else
        notify-send -i video-x-generic "gpu-screen-recorder" "Video recording STOPPED."
    fi
    echo "Recording stopped. File: $RECORDED_FILENAME" >> "$LOG_FILE"
else
    # PID file does not exist, start recording
    CURRENT_FILENAME="$VIDEO_DIR/recording_$(date +%Y%m%d_%H%M%S).$CONTAINER_FORMAT"
    echo "$CURRENT_FILENAME" > "$FILENAME_STORE_FILE" # Store filename for the STOPPED notification

    # Determine recording settings based on HDR status
    GSR_FPS="$SDR_FPS"
    GSR_CODEC="$SDR_CODEC"
    GSR_COLOR_RANGE="$SDR_COLOR_RANGE"
    HDR_MODE_DETECTED="SDR"

    if command -v hyprctl &> /dev/null && command -v jq &> /dev/null; then
        CURRENT_MONITOR_FORMAT=$(hyprctl monitors -j | jq --raw-output ".[] | select(.name == \"$TARGET_MONITOR\") | .currentFormat")

        echo "$TARGET_MONITOR currentFormat: $CURRENT_MONITOR_FORMAT" >> "$LOG_FILE"

        if [ "$CURRENT_MONITOR_FORMAT" == "$HDR_MONITOR_FORMAT_INDICATOR" ]; then
            echo "HDR format ($CURRENT_MONITOR_FORMAT) detected on $TARGET_MONITOR. Using HDR recording settings." >> "$LOG_FILE"
            GSR_FPS="$HDR_FPS"
            GSR_CODEC="$HDR_CODEC"
            GSR_COLOR_RANGE="$HDR_COLOR_RANGE"
            HDR_MODE_DETECTED="HDR"
        else
            echo "SDR format ($CURRENT_MONITOR_FORMAT) or monitor not found. Using SDR settings for $TARGET_MONITOR." >> "$LOG_FILE"
        fi
    else
        echo "hyprctl or jq not found. Defaulting to SDR settings." >> "$LOG_FILE"
    fi

    echo "Starting recording with: Monitor=$TARGET_MONITOR, Codec=$GSR_CODEC, ColorRange=$GSR_COLOR_RANGE, FPS=$GSR_FPS" >> "$LOG_FILE"

    gpu-screen-recorder \
        -w "$TARGET_MONITOR" \
        -f "$GSR_FPS" \
        -k "$GSR_CODEC" \
        -cr "$GSR_COLOR_RANGE" \
        -a "$AUDIO_SOURCE" \
        -c "$CONTAINER_FORMAT" \
        -o "$CURRENT_FILENAME" >> "$LOG_FILE" 2>&1 &

    echo $! > "$PID_FILE"
    echo "$WAYBAR_ICON" > "$STATUS_FILE" # Set recording status for Waybar
    notify-send -i video-x-generic "gpu-screen-recorder" "Video recording STARTED\nOutput: $CURRENT_FILENAME\nMode: $HDR_MODE_DETECTED on $TARGET_MONITOR"
    echo "gpu-screen-recorder started. PID: $!, Output: $CURRENT_FILENAME, Mode: $HDR_MODE_DETECTED on $TARGET_MONITOR" >> "$LOG_FILE"
fi

exit 0
