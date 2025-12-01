pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Core

Singleton {
  id: root

  property string cpuGovernor: "Unknown"
  property string energyPerformance: "Unknown"
  property bool hasPPD: false
  property int kbdOnAC: 3
  property int kbdOnBattery: 1
  property int onACBrightness: 100
  readonly property bool onBattery: BatteryService.isOnBattery
  property int onBatteryBrightness: 10
  readonly property string platformInfo: "Platform: " + platformProfile
  property string platformProfile: "Unknown"
  readonly property string ppdInfo: "PPD: " + ppdProfile
  property string ppdProfile: "Unknown"

  function adjustBrightness(): void {
    if (!BatteryService.isLaptopBattery)
      return;
    if (BrightnessService.ready)
      BrightnessService.setBrightness(onBattery ? onBatteryBrightness : onACBrightness);
    if (KeyboardBacklightService.ready)
      KeyboardBacklightService.setLevel(onBattery ? kbdOnBattery : kbdOnAC);
  }

  function refreshPowerInfo(): void {
    refreshDebounce.restart();
  }

  Component.onCompleted: refreshPowerInfo()
  onOnBatteryChanged: {
    refreshPowerInfo();
    adjustBrightness();
  }

  Connections {
    function onIsLaptopBatteryChanged(): void {
      root.refreshPowerInfo();
    }

    target: BatteryService
  }

  Timer {
    id: refreshDebounce

    interval: 80

    onTriggered: {
      powerInfoProcess.running = true;
      if (BatteryService.isLaptopBattery)
        ppdProcess.running = true;
    }
  }

  // Single process reads all sysfs power info at once
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
        const idx = line.indexOf(":");
        if (idx < 0)
          return;
        const key = line.substring(0, idx);
        const value = line.substring(idx + 1).trim() || "Unknown";
        if (key === "platform")
          root.platformProfile = value;
        else if (key === "governor")
          root.cpuGovernor = value;
        else if (key === "epp")
          root.energyPerformance = value;
      }
    }
  }

  Process {
    id: ppdProcess

    command: ["powerprofilesctl", "get"]

    stdout: StdioCollector {
      onStreamFinished: {
        const result = text.trim();
        root.hasPPD = result.length > 0;
        root.ppdProfile = result || "Unknown";
      }
    }
  }
}
