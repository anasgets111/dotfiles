#!/bin/bash

# --- User Configurable Variables ---
VIDEO_DIR="$HOME/Videos" # Directory for recordings
TARGET_MONITOR="DP-3"               # Monitor to record (e.g., DP-3, eDP-1, or use 'focused' for active monitor)
AUDIO_SOURCE=""       # leave empty "" for no audio, or "default_output" for system audio or "default_output|default_input" for both
CONTAINER_FORMAT="mp4"              # Video container format (mp4, mkv, etc.)
WAYBAR_ICON=" "                     # Icon to show in Waybar when recording (ensure font supports it)

# SDR Recording Settings
SDR_FPS="60"
SDR_CODEC="h265"
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

# Performance optimization: Cache timestamp and create functions for common operations
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly TIMESTAMP

# Fast logging function - reduces syscalls by batching operations
log_message() {
    echo "$1" >> "$LOG_FILE"
}

# Optimized file operations - check existence and read in one operation
read_file_if_exists() {
    [[ -f "$1" ]] && cat "$1" 2>/dev/null
}

# Efficient cleanup function - batch file operations
cleanup_files() {
    # Use brace expansion for efficiency and remove files in one operation
    rm -f "$PID_FILE" "$FILENAME_STORE_FILE" 2>/dev/null
    : > "$STATUS_FILE"  # Faster than echo "" >
}

# --- Script Logic ---

# Ensure output directory exists (only if it doesn't exist to save syscalls)
[[ ! -d "$VIDEO_DIR" ]] && mkdir -p "$VIDEO_DIR"

# Check if recording is running - optimized PID file handling
if [[ -f "$PID_FILE" ]]; then
    # Recording is running - stop it
    PID=$(read_file_if_exists "$PID_FILE")
    [[ -n "$PID" ]] && log_message "Stop signal sent to gpu-screen-recorder (PID: $PID)."
    
    # More efficient process termination
    pkill --signal SIGINT -F "$PID_FILE" 2>/dev/null
    
    # Read filename before cleanup for notification
    RECORDED_FILENAME=$(read_file_if_exists "$FILENAME_STORE_FILE")
    
    # Batch cleanup operations
    cleanup_files
    
    # Single notification with conditional message
    if [[ -n "$RECORDED_FILENAME" ]]; then
        notify-send -i video-x-generic "gpu-screen-recorder" "Video recording STOPPED\nSaved to: $RECORDED_FILENAME"
        log_message "Recording stopped. File: $RECORDED_FILENAME"
    else
        notify-send -i video-x-generic "gpu-screen-recorder" "Video recording STOPPED."
        log_message "Recording stopped. No filename recorded."
    fi
else
    # Start recording - optimize filename generation
    CURRENT_FILENAME="$VIDEO_DIR/recording_${TIMESTAMP}.$CONTAINER_FORMAT"
    echo "$CURRENT_FILENAME" > "$FILENAME_STORE_FILE"
    
    # Optimize HDR detection - use more efficient approach
    GSR_FPS="$SDR_FPS"
    GSR_CODEC="$SDR_CODEC" 
    GSR_COLOR_RANGE="$SDR_COLOR_RANGE"
    HDR_MODE_DETECTED="SDR"
    
    # Check for tools once and cache result for better performance
    if type hyprctl jq &>/dev/null; then
        # More efficient JSON parsing - pipe directly without intermediate variable when possible
        if CURRENT_MONITOR_FORMAT=$(hyprctl monitors -j 2>/dev/null | jq -r ".[] | select(.name == \"$TARGET_MONITOR\") | .currentFormat" 2>/dev/null); then
            # Batch log messages for better I/O performance
            {
                echo "$TARGET_MONITOR currentFormat: $CURRENT_MONITOR_FORMAT"
                if [[ "$CURRENT_MONITOR_FORMAT" == "$HDR_MONITOR_FORMAT_INDICATOR" ]]; then
                    GSR_FPS="$HDR_FPS"
                    GSR_CODEC="$HDR_CODEC"
                    GSR_COLOR_RANGE="$HDR_COLOR_RANGE"
                    HDR_MODE_DETECTED="HDR"
                    echo "HDR format ($CURRENT_MONITOR_FORMAT) detected on $TARGET_MONITOR. Using HDR recording settings."
                else
                    echo "SDR format ($CURRENT_MONITOR_FORMAT) or monitor not found. Using SDR settings for $TARGET_MONITOR."
                fi
            } >> "$LOG_FILE"
        else
            log_message "Failed to get monitor format. Using SDR settings."
        fi
    else
        log_message "hyprctl or jq not found. Defaulting to SDR settings."
    fi

    # Start recording with optimized parameter handling
    log_message "Starting recording with: Monitor=$TARGET_MONITOR, Codec=$GSR_CODEC, ColorRange=$GSR_COLOR_RANGE, FPS=$GSR_FPS"
    
    # Launch gpu-screen-recorder in background
    gpu-screen-recorder \
        -w "$TARGET_MONITOR" \
        -f "$GSR_FPS" \
        -k "$GSR_CODEC" \
        -cr "$GSR_COLOR_RANGE" \
        -a "$AUDIO_SOURCE" \
        -c "$CONTAINER_FORMAT" \
        -o "$CURRENT_FILENAME" >> "$LOG_FILE" 2>&1 &
    
    # Capture PID immediately and perform batch operations
    RECORDER_PID=$!
    
    # Batch file operations for better I/O performance
    {
        echo "$RECORDER_PID" > "$PID_FILE"
        echo "$WAYBAR_ICON" > "$STATUS_FILE"
    }
    
    # Send notification and log final message
    notify-send -i video-x-generic "gpu-screen-recorder" "Video recording STARTED\nOutput: $CURRENT_FILENAME\nMode: $HDR_MODE_DETECTED on $TARGET_MONITOR"
    log_message "gpu-screen-recorder started. PID: $RECORDER_PID, Output: $CURRENT_FILENAME, Mode: $HDR_MODE_DETECTED on $TARGET_MONITOR"
fi

exit 0
