pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Core
import qs.Services.Utils
import qs.Services.WM

Singleton {
  id: root

  property string cpuGovernor: "Unknown"
  property string energyPerformance: "Unknown"
  property string platformProfile: "Unknown"
  property string ppdProfile: ""

  function adjustBrightness(): void {
    if (!BatteryService.isLaptopBattery)
      return;
    if (BrightnessService.ready)
      BrightnessService.setBrightness(BatteryService.isOnBattery ? 10 : 100);
    if (KeyboardBacklightService.ready)
      KeyboardBacklightService.setLevel(BatteryService.isOnBattery ? 1 : 3);
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
  function suspend(): void {
    Command.detached(["systemctl", "suspend"]);
  }
  function suspendIfBatteryCritical(): void {
    if (BatteryService.isSuspendingAndNotCharging)
      root.suspend();
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
      if (BatteryService.isLaptopBattery)
        Command.run(["powerprofilesctl", "get"], result => root.ppdProfile = result.stdout.trim(), "power.ppd");
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
