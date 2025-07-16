#!/usr/bin/env bash
# Check for batteries in various locations and naming schemes
# Returns exit code 0 if batteries are found, 1 if none found

# Common battery paths to check
BATTERY_PATHS=(
    "/sys/class/power_supply/BAT*"
    "/sys/class/power_supply/battery*"
    "/sys/class/power_supply/ADP*"
    "/sys/class/power_supply/AC*"
    "/proc/acpi/battery/*"
)

# Check each path
for path in "${BATTERY_PATHS[@]}"; do
    if ls $path 2>/dev/null | grep -E "(BAT|battery)" >/dev/null 2>&1; then
        exit 0
    fi
done

# Additional check for UPower batteries
if command -v upower >/dev/null 2>&1; then
    if upower -i $(upower -e | grep 'BAT') 2>/dev/null | grep -q "Device:"; then
        exit 0
    fi
fi

# No batteries found
exit 1
