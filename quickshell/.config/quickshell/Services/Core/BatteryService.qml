pragma Singleton
import Quickshell
import Quickshell.Services.UPower
import qs.Services
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: root

  property var _notifyTimestamps: ({})
  readonly property var device: UPower.displayDevice
  readonly property int deviceState: device?.state ?? UPowerDeviceState.Unknown
  readonly property bool isACPowered: isCharging || isFullyCharged || isPendingCharge
  readonly property bool isCharging: deviceState === UPowerDeviceState.Charging
  readonly property bool isCriticalAndNotCharging: isLaptopBattery && !isCharging && percentageFraction <= 0.1
  readonly property bool isDischarging: deviceState === UPowerDeviceState.Discharging
  readonly property bool isEmptyState: deviceState === UPowerDeviceState.Empty
  readonly property bool isFullyCharged: deviceState === UPowerDeviceState.FullyCharged
  readonly property bool isLaptopBattery: device?.type === UPowerDeviceType.Battery && device?.isPresent
  readonly property bool isLowAndNotCharging: isLaptopBattery && !isCharging && percentageFraction <= 0.2
  readonly property bool isOnBattery: isDischarging || isPendingDischarge
  readonly property bool isPendingCharge: deviceState === UPowerDeviceState.PendingCharge
  readonly property bool isPendingDischarge: deviceState === UPowerDeviceState.PendingDischarge
  readonly property bool isReady: MainService.isLaptop && isLaptopBattery
  readonly property bool isSuspendingAndNotCharging: isLaptopBattery && !isCharging && percentageFraction <= 0.08
  readonly property bool isUnknownState: deviceState === UPowerDeviceState.Unknown
  readonly property int percentage: Math.round(percentageFraction * 100)
  readonly property real percentageFraction: {
    const raw = device?.percentage ?? 0;
    return Math.max(0, Math.min(raw > 1 ? raw / 100 : raw, 1));
  }
  readonly property string timeToEmptyText: {
    if (!device)
      return qsTr("Unknown");
    if (!isCharging && device.timeToEmpty > 0)
      return qsTr("Time remaining: %1").arg(TimeService.formatHM(device.timeToEmpty));
    return qsTr("Calculating…");
  }
  readonly property string timeToFullText: {
    if (!device)
      return qsTr("Unknown");
    if (isFullyCharged)
      return qsTr("Fully Charged");
    if (isPendingCharge)
      return qsTr("Charge Limit Reached");
    if (isCharging && device.timeToFull > 0)
      return qsTr("Time to full: %1").arg(TimeService.formatHM(device.timeToFull));
    return qsTr("Calculating…");
  }

  function sendNotification(summary: string, body: string, isCritical: bool): void {
    const key = `${summary}|${isCritical}`;
    const now = Date.now();
    if (now - (_notifyTimestamps[key] ?? 0) < 15000)
      return;

    _notifyTimestamps[key] = now;
    Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", isCritical ? "critical" : "normal", "-t", "5000", "-e", summary, body]);
  }

  onIsCriticalAndNotChargingChanged: {
    if (isCriticalAndNotCharging)
      sendNotification(qsTr("Critical Battery"), qsTr("Automatic suspend at 5%!"), true);
  }
  onIsLowAndNotChargingChanged: {
    if (isLowAndNotCharging)
      sendNotification(qsTr("Low Battery"), qsTr("Plug in soon!"), false);
  }
  onIsReadyChanged: {
    if (isReady) {
      Logger.log("BatteryService", `Battery ready: ${device?.nativePath ?? "(no path)"}, ${percentage}%`);
    } else {
      Logger.log("BatteryService", "Battery device lost");
    }
  }
  onIsSuspendingAndNotChargingChanged: {
    if (isSuspendingAndNotCharging)
      Quickshell.execDetached(["systemctl", "suspend"]);
  }
}
