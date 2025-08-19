pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Services.SystemInfo

Singleton {
    id: batteryService

    // Tracks whether this service has detected a usable laptop battery.
    // Other components can check `isReady` to know when battery-derived
    // properties (like `percentage`) are valid.
    readonly property bool isReady: isLaptopBattery
    readonly property var logger: LoggerService
    // Live reference to the UPower display device object.
    readonly property var displayDevice: UPower.displayDevice

    // Log readiness transitions
    onIsReadyChanged: {
        if (isReady) {
            logger.log("BatteryService", "Battery device ready:", displayDevice && (displayDevice.nativePath || "(no nativePath)"));
            logger.log("BatteryService", "Initial percentage:", percentage + "%");
        } else {
            logger.log("BatteryService", "Battery device lost or not present anymore");
        }
    }

    // Derived, read-only properties that present the battery status in
    // easy-to-consume forms.
    readonly property bool isLaptopBattery: displayDevice && displayDevice.type === UPowerDeviceType.Battery && displayDevice.isPresent

    // Provide percentage both as a normalized fraction (0..1) and as an
    // integer 0..100 for display purposes. This handles backends that use
    // either format.
    readonly property real percentageFraction: displayDevice ? Math.max(0, Math.min((displayDevice.percentage > 1 ? displayDevice.percentage / 100 : displayDevice.percentage), 1)) : 0
    readonly property int percentage: Math.round(percentageFraction * 100)

    // Charging/connectivity flags derived from UPower states.
    readonly property bool isCharging: displayDevice && displayDevice.state === UPowerDeviceState.Charging
    readonly property bool isPluggedIn: displayDevice && (displayDevice.state === UPowerDeviceState.Charging || displayDevice.state === UPowerDeviceState.PendingCharge)

    // Convenience booleans for common alert thresholds. These combine the
    // presence check with the percentage and charging state to simplify UI
    // logic (e.g., show warnings only when on battery).
    readonly property bool isLowAndNotCharging: isLaptopBattery && percentageFraction <= 0.2 && !isCharging
    readonly property bool isCriticalAndNotCharging: isLaptopBattery && percentageFraction <= 0.1 && !isCharging
    readonly property bool isSuspendingAndNotCharging: isLaptopBattery && percentageFraction <= 0.08 && !isCharging

    // Human-readable strings for UI display. These prefer UPower's time
    // estimates when available; otherwise they return a short fallback.
    readonly property string timeToFullText: {
        if (!displayDevice)
            return "Unknown";
        if (displayDevice.state === UPowerDeviceState.FullyCharged)
            return "Fully Charged";
        if (isCharging && displayDevice.timeToFull > 0)
            return "Time to full: " + TimeService.formatHM(displayDevice.timeToFull);
        if (displayDevice.state === UPowerDeviceState.PendingCharge)
            return "Charge Limit Reached";
        return "Calculating…";
    }

    readonly property string timeToEmptyText: {
        if (!displayDevice)
            return "Unknown";
        if (!isCharging && displayDevice.timeToEmpty > 0)
            return "Time remaining: " + TimeService.formatHM(displayDevice.timeToEmpty);
        return "Calculating…";
    }
}
