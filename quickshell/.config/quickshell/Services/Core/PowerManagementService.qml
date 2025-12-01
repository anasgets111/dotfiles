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

  function adjustBrightness(): void {
    if (!isLaptop)
      return;

    if (BrightnessService.ready) {
      BrightnessService.setBrightness(onBattery ? onBatteryBrightness : onACBrightness);
    }
    if (KeyboardBacklightService.ready) {
      KeyboardBacklightService.setLevel(onBattery ? kbdOnBattery : kbdOnAC);
    }
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
      powerInfoProcess.running = true;
      if (root.isLaptop) {
        ppdProcess.running = true;
        tlpCheckProcess.running = true;
      }
    }
  }

  Process {
    id: setProfileProcess

    onRunningChanged: if (!running)
      root.refreshPowerInfo()
  }

  Process {
    id: powerInfoProcess

    command: ["sh", "-c", `
      echo "platform:$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo Unknown)"
      echo "governor:$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo Unknown)"
      echo "epp:$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo Unknown)"
    `]

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: line => {
        const parts = line.split(":");
        if (parts.length < 2)
          return;
        const key = parts[0];
        const val = parts.slice(1).join(":").trim() || "Unknown";
        if (key === "platform")
          root.platformProfile = val;
        else if (key === "governor")
          root.cpuGovernor = val;
        else if (key === "epp")
          root.energyPerformance = val;
      }
    }
  }

  Process {
    id: ppdProcess

    command: ["powerprofilesctl", "get"]

    stdout: StdioCollector {
      onStreamFinished: root._ppdRaw = text.trim()
    }
  }

  Process {
    id: tlpCheckProcess

    command: ["tlpctl", "get"]

    stdout: StdioCollector {
      onStreamFinished: root._tlpRaw = text.trim()
    }
  }
}
