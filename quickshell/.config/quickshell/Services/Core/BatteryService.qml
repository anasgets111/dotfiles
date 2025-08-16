pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Services as Services

Singleton {
    id: batteryService

    // Tracks whether this service has detected a usable laptop battery.
    // Other components can check `isReady` to know when battery-derived
    // properties (like `percentage`) are valid.
    property bool isReady: false

    // Live reference to the UPower display device object.
    property var displayDevice: UPower.displayDevice

    Component.onCompleted: {
        // Ensure we reflect the current device on startup
        displayDevice = UPower.displayDevice;
        console.log("[BatteryService] Initial device object present");
        updateReadyState();
    }

    // Re-evaluate readiness any time UPower reports a new device object.
    onDisplayDeviceChanged: updateReadyState()

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
            return "Time to full: " + Services.TimeService.formatHM(displayDevice.timeToFull);
        if (displayDevice.state === UPowerDeviceState.PendingCharge)
            return "Charge Limit Reached";
        return "Calculating…";
    }

    readonly property string timeToEmptyText: {
        if (!displayDevice)
            return "Unknown";
        if (!isCharging && displayDevice.timeToEmpty > 0)
            return "Time remaining: " + Services.TimeService.formatHM(displayDevice.timeToEmpty);
        return "Calculating…";
    }

    // Update `isReady` based on whether a valid laptop battery is present.
    function updateReadyState() {
        if (isLaptopBattery && !isReady) {
            console.log("[BatteryService] Battery device ready:", displayDevice && (displayDevice.nativePath || "(no nativePath)"));
            console.log("[BatteryService] Initial percentage:", percentage + "%");
            isReady = true;
        } else if (!isLaptopBattery && isReady) {
            console.log("[BatteryService] Battery device lost or not present anymore");
            isReady = false;
        }
    }
}
