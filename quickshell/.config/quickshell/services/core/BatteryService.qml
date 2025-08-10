pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../" as Services

Singleton {
    id: batteryService

    // Lifecycle
    property bool ready: false

    // Direct reference to UPower's display device
    property var upowerDevice: UPower.displayDevice

    // Core battery state
    readonly property bool isLaptopBattery: upowerDevice && upowerDevice.type === UPowerDeviceType.Battery && upowerDevice.isPresent
    readonly property real percentageFraction: upowerDevice ? Math.max(0, Math.min(upowerDevice.percentage, 1)) : 0 // 0–1
    readonly property real percentage: Math.round(percentageFraction * 100) // 0–100 for display
    readonly property bool isCharging: upowerDevice && upowerDevice.state === UPowerDeviceState.Charging
    readonly property bool isPluggedIn: upowerDevice && (upowerDevice.state === UPowerDeviceState.Charging || upowerDevice.state === UPowerDeviceState.PendingCharge)

    // Threshold states
    readonly property bool isLowAndNotCharging: isLaptopBattery && percentageFraction <= 0.2 && !isCharging
    readonly property bool isCriticalAndNotCharging: isLaptopBattery && percentageFraction <= 0.1 && !isCharging
    readonly property bool isSuspendingAndNotCharging: isLaptopBattery && percentageFraction <= 0.05 && !isCharging

    // Time estimates
    readonly property string timeToFullText: {
        if (!upowerDevice)
            return "Unknown";
        if (upowerDevice.state === UPowerDeviceState.FullyCharged)
            return "Fully Charged";
        if (isCharging && upowerDevice.timeToFull > 0)
            return "Time to full: " + Services.TimeService.formatHM(upowerDevice.timeToFull);
        if (upowerDevice.state === UPowerDeviceState.PendingCharge)
            return "Charge Limit Reached";
        return "Calculating…";
    }

    readonly property string timeToEmptyText: {
        if (!upowerDevice)
            return "Unknown";
        if (!isCharging && upowerDevice.timeToEmpty > 0)
            return "Time remaining: " + Services.TimeService.formatHM(upowerDevice.timeToEmpty);
        return "Calculating…";
    }

    // Reactively check readiness
    onUpowerDeviceChanged: checkReady()
    onIsLaptopBatteryChanged: checkReady()

    Component.onCompleted: {
        upowerDevice = UPower.displayDevice;
        console.log("[BatteryService] Initial device object present");
        checkReady();
    }

    function checkReady() {
        if (isLaptopBattery && !ready) {
            console.log("[BatteryService] Battery device ready:", upowerDevice.nativePath || "(no nativePath)");
            console.log("[BatteryService] Initial percentage:", percentage + "%");
            ready = true;
        }
    }
}
