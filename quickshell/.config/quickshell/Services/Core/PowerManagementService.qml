pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Core

Singleton {
  id: root

  property string _ppdRaw: ""
  property string _tlpRaw: ""
  property string cpuGovernor: "Unknown"
  property string energyPerformance: "Unknown"
  readonly property bool hasPPD: _ppdRaw !== ""
  readonly property bool hasTlp: _tlpRaw !== ""
  readonly property bool isLaptop: BatteryService.isLaptopBattery
  property int kbdOnAC: 3
  property int kbdOnBattery: 1
  property int onACBrightness: 100
  readonly property bool onBattery: BatteryService.isOnBattery
  property int onBatteryBrightness: 10
  readonly property string platformInfo: "Platform: " + platformProfile
  property string platformProfile: "Unknown"
  readonly property string ppdInfo: "PPD: " + ppdProfile
  readonly property string ppdProfile: hasPPD ? _ppdRaw : (hasTlp ? _tlpRaw : "Unknown")

  function reboot(): void {
    Quickshell.execDetached(["systemctl", "reboot"]);
  }

  function poweroff(): void {
    Quickshell.execDetached(["systemctl", "poweroff"]);
  }

  function suspend(): void {
    Quickshell.execDetached(["systemctl", "suspend"]);
  }

  function logout(): void {
    Quickshell.execDetached(["sh", "-c", "loginctl terminate-user $USER"]);
  }

  function adjustBrightness(): void {
    if (!isLaptop)
      return;
    if (BrightnessService.ready)
      BrightnessService.setBrightness(onBattery ? onBatteryBrightness : onACBrightness);
    if (KeyboardBacklightService.ready)
      KeyboardBacklightService.setLevel(onBattery ? kbdOnBattery : kbdOnAC);
  }

  function refreshPowerInfo(): void {
    refreshDebounce.restart();
  }

  function setPowerProfile(profile: string): void {
    if (hasPPD) {
      setProfileProcess.command = ["powerprofilesctl", "set", profile];
      setProfileProcess.running = true;
    } else if (hasTlp) {
      setProfileProcess.command = ["tlpctl", profile];
      setProfileProcess.running = true;
    }
  }

  Component.onCompleted: refreshPowerInfo()

  Connections {
    function onIsLaptopBatteryChanged() {
      root.refreshPowerInfo();
    }

    function onIsOnBatteryChanged() {
      root.refreshPowerInfo();
      root.adjustBrightness();
    }

    target: BatteryService
  }

  Timer {
    id: refreshDebounce

    interval: 100

    onTriggered: {
      platformFile.reload();
      governorFile.reload();
      eppFile.reload();
      if (root.isLaptop) {
        ppdProcess.running = true;
        tlpCheckProcess.running = true;
      }
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

  Process {
    id: setProfileProcess

    onRunningChanged: if (!running)
      root.refreshPowerInfo()
  }

  Process {
    id: ppdProcess

    command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]

    stdout: StdioCollector {
      onStreamFinished: root._ppdRaw = text.trim()
    }
  }

  Process {
    id: tlpCheckProcess

    command: ["sh", "-c", "tlpctl get 2>/dev/null"]

    stdout: StdioCollector {
      onStreamFinished: root._tlpRaw = text.trim()
    }
  }
}
