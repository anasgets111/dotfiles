pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: root

  property bool _glitchActive: false
  property var _notifyTimestamps: ({})
  readonly property real criticalThreshold: 0.1
  readonly property var device: UPower.displayDevice
  readonly property int deviceState: device?.state ?? UPowerDeviceState.Unknown
  readonly property bool isACPowered: !isOnBattery
  readonly property bool isCharging: deviceState === UPowerDeviceState.Charging
  readonly property bool isCriticalAndNotCharging: isLaptopBattery && isOnBattery && percentageFraction <= criticalThreshold
  readonly property bool isFullyCharged: deviceState === UPowerDeviceState.FullyCharged
  readonly property bool isLaptopBattery: !!device?.ready && device.type === UPowerDeviceType.Battery && device.isPresent
  readonly property bool isLowAndNotCharging: isLaptopBattery && isOnBattery && percentageFraction <= lowThreshold
  readonly property bool isOnBattery: UPower.onBattery
  readonly property bool isPendingCharge: deviceState === UPowerDeviceState.PendingCharge && !_glitchActive
  readonly property bool isSuspendingAndNotCharging: isLaptopBattery && isOnBattery && percentageFraction <= suspendThreshold
  readonly property real lowThreshold: 0.2
  readonly property int percentage: Math.round(percentageFraction * 100)
  property real percentageFraction: Math.max(0, Math.min(device?.percentage ?? 0, 1))
  readonly property real suspendThreshold: 0.08
  readonly property string timeToEmptyText: {
    if (isOnBattery && (device?.timeToEmpty ?? 0) > 0)
      return qsTr("Time remaining: %1").arg(TimeService.formatHM(device.timeToEmpty));
    return qsTr("Calculating…");
  }
  readonly property string timeToFullText: {
    if (isFullyCharged)
      return qsTr("Fully Charged");
    if (isPendingCharge)
      return qsTr("Charge Limit Reached");
    if (isCharging && (device?.timeToFull ?? 0) > 0)
      return qsTr("Time to full: %1").arg(TimeService.formatHM(device.timeToFull));
    return qsTr("Calculating…");
  }

  function _ingestPercentage(): void {
    const rawFraction = Math.max(0, Math.min(device?.percentage ?? 0, 1));
    // ponytail: UPower occasionally reports a spurious 0% while on AC; hold the last reading
    // and expose the flag so derived states (isPendingCharge) can suppress their own glitch edges.
    // On battery a genuine 0% is indistinguishable from a glitch, so we let it through.
    _glitchActive = isACPowered && rawFraction <= 0 && percentageFraction > 0;
    if (!_glitchActive)
      percentageFraction = rawFraction;
  }
  function _sendNotification(summary: string, body: string, isCritical: bool): void {
    const now = Date.now();
    if (now - (_notifyTimestamps[summary] ?? 0) < 15000)
      return;

    _notifyTimestamps[summary] = now;
    const urgency = isCritical ? "critical" : "normal";
    Command.detached(["notify-send", "-a", "Battery", "-u", urgency, "-t", "5000", "-e", summary, body]);
  }

  Component.onCompleted: _ingestPercentage()
  onIsCriticalAndNotChargingChanged: if (isCriticalAndNotCharging)
    _sendNotification(qsTr("Critical Battery"), qsTr("Automatic suspend at %1%!").arg(Math.round(suspendThreshold * 100)), true)
  onIsLowAndNotChargingChanged: if (isLowAndNotCharging)
    _sendNotification(qsTr("Low Battery"), qsTr("Plug in soon!"), false)

  Connections {
    function onPercentageChanged(): void {
      root._ingestPercentage();
    }

    target: root.device
  }
}
