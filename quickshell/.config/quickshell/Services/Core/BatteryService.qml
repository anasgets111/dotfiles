pragma Singleton
import Quickshell
import Quickshell.Services.UPower
import qs.Services
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: batteryService

  readonly property int deviceState: displayDevice ? displayDevice.state : UPowerDeviceState.Unknown
  readonly property var displayDevice: UPower.displayDevice
  readonly property bool isACPowered: isCharging || isFullyCharged || isPendingCharge
  readonly property bool isCharging: displayDevice && deviceState === UPowerDeviceState.Charging
  readonly property bool isCriticalAndNotCharging: isLaptopBattery && percentageFraction <= 0.1 && !isCharging
  readonly property bool isDischarging: displayDevice && deviceState === UPowerDeviceState.Discharging
  readonly property bool isEmptyState: displayDevice && deviceState === UPowerDeviceState.Empty
  readonly property bool isFullyCharged: displayDevice && deviceState === UPowerDeviceState.FullyCharged
  readonly property bool isLaptopBattery: displayDevice && displayDevice.type === UPowerDeviceType.Battery && displayDevice.isPresent
  readonly property bool isLowAndNotCharging: isLaptopBattery && percentageFraction <= 0.2 && !isCharging
  readonly property bool isOnBattery: isDischarging || isPendingDischarge
  readonly property bool isPendingCharge: displayDevice && deviceState === UPowerDeviceState.PendingCharge
  readonly property bool isPendingDischarge: displayDevice && deviceState === UPowerDeviceState.PendingDischarge
  readonly property bool isPluggedIn: displayDevice && (deviceState === UPowerDeviceState.Charging || deviceState === UPowerDeviceState.PendingCharge)
  readonly property bool isReady: MainService.isLaptop && isLaptopBattery
  readonly property bool isSuspendingAndNotCharging: isLaptopBattery && percentageFraction <= 0.08 && !isCharging
  readonly property bool isUnknownState: deviceState === UPowerDeviceState.Unknown
  readonly property int percentage: Math.round(percentageFraction * 100)
  readonly property real percentageFraction: {
    const rawPercentage = displayDevice ? displayDevice.percentage : 0;
    const normalizedFraction = rawPercentage > 1 ? rawPercentage / 100 : rawPercentage;
    return Math.max(0, Math.min(normalizedFraction, 1));
  }
  readonly property string timeToEmptyText: {
    const device = displayDevice;
    if (!device)
      return qsTr("Unknown");

    if (!isCharging && device.timeToEmpty > 0)
      return qsTr("Time remaining: %1").arg(TimeService.formatHM(device.timeToEmpty));

    return qsTr("Calculating…");
  }
  readonly property string timeToFullText: {
    const device = displayDevice;
    if (!device)
      return qsTr("Unknown");

    const currentState = device.state;
    if (currentState === UPowerDeviceState.FullyCharged)
      return qsTr("Fully Charged");

    if (currentState === UPowerDeviceState.Charging && device.timeToFull > 0)
      return qsTr("Time to full: %1").arg(TimeService.formatHM(device.timeToFull));

    if (currentState === UPowerDeviceState.PendingCharge)
      return qsTr("Charge Limit Reached");

    return qsTr("Calculating…");
  }

  onIsReadyChanged: {
    if (isReady) {
      Logger.log("BatteryService", "Battery device ready:", displayDevice && (displayDevice.nativePath || "(no nativePath)"));
      Logger.log("BatteryService", "Initial percentage:", percentage + "%");
    } else {
      Logger.log("BatteryService", "Battery device lost or not present anymore");
    }
  }
}
