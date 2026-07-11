pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Core
import qs.Services.Utils
import qs.Services.WM

Singleton {
  id: root

  property string _ppdRaw: ""
  property string cpuGovernor: "Unknown"
  property string energyPerformance: "Unknown"
  readonly property bool hasPPD: _ppdRaw !== ""
  readonly property bool isLaptop: BatteryService.isLaptopBattery
  property int kbdOnAC: 3
  property int kbdOnBattery: 1
  property int onACBrightness: 100
  readonly property bool onBattery: BatteryService.isOnBattery
  property int onBatteryBrightness: 10
  property string platformProfile: "Unknown"
  readonly property string ppdProfile: hasPPD ? _ppdRaw : "Unknown"

  function adjustBrightness(): void {
    if (!isLaptop)
      return;
    if (BrightnessService.ready)
      BrightnessService.setBrightness(onBattery ? onBatteryBrightness : onACBrightness);
    if (KeyboardBacklightService.ready)
      KeyboardBacklightService.setLevel(onBattery ? kbdOnBattery : kbdOnAC);
  }

  function logout(): void {
    CompositorService.exitSession();
  }

  function poweroff(): void {
    Command.detached(["systemctl", "poweroff"]);
  }

  function reboot(): void {
    Command.detached(["systemctl", "reboot"]);
  }

  function refreshPowerInfo(): void {
    refreshDebounce.restart();
  }

  function suspendIfBatteryCritical(): void {
    if (BatteryService.isSuspendingAndNotCharging)
      root.suspend();
  }

  function suspend(): void {
    Command.detached(["systemctl", "suspend"]);
  }

  Component.onCompleted: {
    refreshPowerInfo();
    adjustBrightness();
    suspendIfBatteryCritical();
  }

  Connections {
    function onIsLaptopBatteryChanged() {
      root.refreshPowerInfo();
      root.adjustBrightness();
    }

    function onIsOnBatteryChanged() {
      root.refreshPowerInfo();
      root.adjustBrightness();
    }

    function onIsSuspendingAndNotChargingChanged() {
      root.suspendIfBatteryCritical();
    }

    target: BatteryService
  }

  Connections {
    function onReadyChanged(): void {
      if (BrightnessService.ready)
        root.adjustBrightness();
    }

    target: BrightnessService
  }

  Connections {
    function onReadyChanged(): void {
      if (KeyboardBacklightService.ready)
        root.adjustBrightness();
    }

    target: KeyboardBacklightService
  }

  Timer {
    id: refreshDebounce

    interval: 100

    onTriggered: {
      platformFile.reload();
      governorFile.reload();
      eppFile.reload();
      if (root.isLaptop)
        Command.run(["powerprofilesctl", "get"], result => root._ppdRaw = result.stdout.trim(), "power.ppd");
    }
  }

  FileView {
    id: platformFile

    path: "/sys/firmware/acpi/platform_profile"

    onLoaded: root.platformProfile = text().trim() || "Unknown"
  }

  FileView {
    id: governorFile

    path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"

    onLoaded: root.cpuGovernor = text().trim() || "Unknown"
  }

  FileView {
    id: eppFile

    path: "/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"

    onLoaded: root.energyPerformance = text().trim() || "Unknown"
  }
}
