pragma Singleton
import Quickshell
import Quickshell.Services.UPower
import qs.Services
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: batteryService

  property var lastNotificationTimestamps: ({})
  readonly property int deviceState: UPower.displayDevice ? UPower.displayDevice.state : UPowerDeviceState.Unknown
  readonly property bool isACPowered: isCharging || isFullyCharged || isPendingCharge
  readonly property bool isCharging: deviceState === UPowerDeviceState.Charging
  readonly property bool isCriticalAndNotCharging: isLaptopBattery && percentageFraction <= 0.1 && !isCharging
  readonly property bool isDischarging: deviceState === UPowerDeviceState.Discharging
  readonly property bool isEmptyState: deviceState === UPowerDeviceState.Empty
  readonly property bool isFullyCharged: deviceState === UPowerDeviceState.FullyCharged
  readonly property bool isLaptopBattery: !!UPower.displayDevice && UPower.displayDevice.type === UPowerDeviceType.Battery && UPower.displayDevice.isPresent
  readonly property bool isLowAndNotCharging: isLaptopBattery && percentageFraction <= 0.2 && !isCharging
  readonly property bool isOnBattery: isDischarging || isPendingDischarge
  readonly property bool isPendingCharge: deviceState === UPowerDeviceState.PendingCharge
  readonly property bool isPendingDischarge: deviceState === UPowerDeviceState.PendingDischarge
  readonly property bool isReady: MainService.isLaptop && isLaptopBattery
  readonly property bool isSuspendingAndNotCharging: isLaptopBattery && percentageFraction <= 0.08 && !isCharging
  readonly property bool isUnknownState: deviceState === UPowerDeviceState.Unknown
  readonly property int percentage: Math.round(percentageFraction * 100)
  readonly property real percentageFraction: {
    const rawPercentage = UPower.displayDevice ? UPower.displayDevice.percentage : 0;
    const normalizedFraction = rawPercentage > 1 ? rawPercentage / 100 : rawPercentage;
    return Math.max(0, Math.min(normalizedFraction, 1));
  }
  readonly property string timeToEmptyText: {
    if (!UPower.displayDevice)
      return qsTr("Unknown");

    if (!isCharging && UPower.displayDevice.timeToEmpty > 0)
      return qsTr("Time remaining: %1").arg(TimeService.formatHM(UPower.displayDevice.timeToEmpty));

    return qsTr("Calculating…");
  }
  readonly property string timeToFullText: {
    const device = UPower.displayDevice;
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

  function handleCriticalState() {
    if (batteryService.isCriticalAndNotCharging)
      batteryService.sendNotification(qsTr("Critical Battery"), qsTr("Automatic suspend at 5%!"), true);
  }

  function handleLowState() {
    if (batteryService.isLowAndNotCharging)
      batteryService.sendNotification(qsTr("Low Battery"), qsTr("Plug in soon!"), false);
  }

  function handleSuspendingState() {
    if (batteryService.isSuspendingAndNotCharging)
      Quickshell.execDetached(["systemctl", "suspend"]); // detached, non-blocking

  }

  function sendNotification(summary, body, isCritical) {
    if (!batteryService.lastNotificationTimestamps)
      batteryService.lastNotificationTimestamps = {};

    const summaryText = String(summary == null ? "" : summary);
    const bodyText = String(body == null ? "" : body);
    const key = summaryText + "|" + (isCritical ? "1" : "0");
    const now = Date.now();
    const last = batteryService.lastNotificationTimestamps[key] || 0;
    if (now - last < 15000)
      return;

    batteryService.lastNotificationTimestamps[key] = now;
    const urgency = isCritical ? "critical" : "normal";
    const args = ["notify-send", "-a", "Battery", "-u", urgency, "-t", "5000", "-e", summaryText, bodyText];
    Utils.runCmd(args, function () {}, batteryService);
  }

  onIsCriticalAndNotChargingChanged: batteryService.handleCriticalState()
  onIsLowAndNotChargingChanged: batteryService.handleLowState()
  onIsReadyChanged: {
    if (batteryService.isReady) {
      Logger.log("BatteryService", "Battery device ready:", UPower.displayDevice && (UPower.displayDevice.nativePath || "(no nativePath)"));
      Logger.log("BatteryService", "Initial percentage:", batteryService.percentage + "%");
    } else {
      Logger.log("BatteryService", "Battery device lost or not present anymore");
    }
  }
  onIsSuspendingAndNotChargingChanged: batteryService.handleSuspendingState()
}
