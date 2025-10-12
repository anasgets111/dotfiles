pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Core

Singleton {
  id: pms

  property string cpuGovernor: "Unknown"
  property string energyPerformance: "Unknown"
  property bool hasPPD: false
  property int kbdOnAC: 3
  property int kbdOnBattery: 1

  // Brightness settings
  property int onACBrightness: 100

  // Reflect whether the system is currently running on battery power
  property bool onBattery: BatteryService.isOnBattery
  property int onBatteryBrightness: 10
  readonly property string platformInfo: "Platform: " + pms.platformProfile
  property string platformProfile: "Loading..."
  readonly property string ppdInfo: "PPD: " + pms.ppdText
  property string ppdText: "Loading..."

  function _doRefreshPowerInfo() {
    // Platform profile
    pms.readFile("/sys/firmware/acpi/platform_profile", function (data) {
      pms.platformProfile = data;
    });
    // CPU governor
    pms.readFile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", function (data) {
      pms.cpuGovernor = data;
    });
    // EPP
    pms.readFile("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference", function (data) {
      pms.energyPerformance = data;
    });
    if (BatteryService.isLaptopBattery && pms.hasPPD)
      ppdProcess.running = true;
  }

  function adjustBrightness() {
    if (!BatteryService.isLaptopBattery)
      return;

    // Adjust screen brightness
    if (BrightnessService.ready) {
      const targetPercent = pms.onBattery ? pms.onBatteryBrightness : pms.onACBrightness;
      BrightnessService.setBrightness(targetPercent);
    }

    // Adjust keyboard backlight
    if (KeyboardBacklightService.ready) {
      const targetLevel = pms.onBattery ? pms.kbdOnBattery : pms.kbdOnAC;
      KeyboardBacklightService.setLevel(targetLevel);
    }
  }

  // Minimal one-shot reader utility
  function readFile(path, cb) {
    const p = readProcessComponent.createObject(pms, {
      command: ["cat", path]
    });
    p.stdout.streamFinished.connect(function () {
      const data = p.stdout.text?.trim() || "";
      try {
        cb(data);
      } finally {
        p.destroy();
      }
    });
    p.running = true;
  }

  function refreshPowerInfo() {
    _refreshDebounce.restart();
  }

  Component.onCompleted: pms.refreshPowerInfo()
  Component.onDestruction: {
    ppdProcess.running = false;
    try {
      ppdProcess.destroy();
    } catch (_) {}
    try {
      ppdCheck.destroy();
    } catch (_) {}
  }
  onOnBatteryChanged: {
    pms.refreshPowerInfo();
    pms.adjustBrightness();
  }

  // Listen to BatteryService for laptop detection changes
  Connections {
    function onIsLaptopBatteryChanged() {
      pms.refreshPowerInfo();
    }

    target: BatteryService
  }

  // Debounce timer for refreshPowerInfo to avoid rapid repeated spawns
  Timer {
    id: _refreshDebounce

    interval: 80
    repeat: false

    onTriggered: pms._doRefreshPowerInfo()
  }

  Component {
    id: readProcessComponent

    Process {
      running: false

      stdout: StdioCollector {
      }
    }
  }

  Process {
    id: ppdProcess

    command: ["powerprofilesctl", "get"]
    running: false

    stdout: StdioCollector {
      id: ppdStdout

      onStreamFinished: {
        pms.ppdText = ppdStdout.text.trim() || "Unknown";
      }
    }
  }

  // Small check to detect if powerprofilesctl exists on the system
  Process {
    id: ppdCheck

    command: ["sh", "-c", "if command -v powerprofilesctl >/dev/null 2>&1; then echo yes; else echo no; fi"]
    running: true

    stdout: StdioCollector {
      id: ppdCheckStdout

      onStreamFinished: {
        pms.hasPPD = ppdCheckStdout.text.trim() === "yes";
        if (pms.hasPPD && BatteryService.isLaptopBattery)
          ppdProcess.running = true;
      }
    }
  }
}
