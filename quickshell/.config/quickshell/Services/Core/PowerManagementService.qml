pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Core

Singleton {
  id: pms

  property string cpuGovernor: "Unknown"
  property string energyPerformance: "Unknown"
  // whether powerprofilesctl (ppd) is available on this host
  property bool hasPPD: false
  property string kbdDevice: "asus::kbd_backlight"
  property int kbdOnAC: 3
  property int kbdOnBattery: 1
  property int onACBrightness: 100
  // reflect whether the system is currently running on battery power
  property bool onBattery: BatteryService.isOnBattery

  // Tunables
  property int onBatteryBrightness: 10
  readonly property string platformInfo: "Platform: " + pms.platformProfile
  property string platformProfile: "Loading..."
  readonly property string ppdInfo: "PPD: " + pms.ppdText
  property string ppdText: "Loading..."

  signal powerInfoUpdated
  signal thermalInfoUpdated

  function adjustBrightness() {
    // only attempt to adjust if this is a laptop
    if (!BatteryService.isLaptopBattery)
      return;

    const screen = pms.onBattery ? pms.onBatteryBrightness : pms.onACBrightness;
    const kbd = pms.onBattery ? pms.kbdOnBattery : pms.kbdOnAC;
    const cmd = "brightnessctl set " + screen + "% && brightnessctl -d " + pms.kbdDevice + " set " + kbd;

    brightnessProcess.command = ["sh", "-c", cmd];
    if (brightnessDebounce.running)
      brightnessDebounce.restart();
    else
      brightnessDebounce.start();
  }

  // Minimal one-shot reader utility (avoids implicit this/try/catch)
  function readFile(path, cb) {
    const p = readProcessComponent.createObject(pms, {
      command: ["cat", path]
    });
    p.stdout.streamFinished.connect(function () {
      const data = p.stdout.text ? p.stdout.text.trim() : "";
      cb(data);
      p.destroy();
    });
    p.running = true;
  }
  function refreshPowerInfo() {
    // Debounced entry point: schedule actual work to coalesce bursts
    if (_refreshDebounce.running)
      _refreshDebounce.restart();
    else
      _refreshDebounce.start();
  }
  function _doRefreshPowerInfo() {
    // Platform profile
    pms.readFile("/sys/firmware/acpi/platform_profile", function (data) {
      pms.platformProfile = data;
      pms.powerInfoUpdated();
    });
    // CPU governor
    pms.readFile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", function (data) {
      pms.cpuGovernor = data;
      pms.thermalInfoUpdated();
    });
    // EPP
    pms.readFile("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference", function (data) {
      pms.energyPerformance = data;
      pms.thermalInfoUpdated();
    });
    if (BatteryService.isLaptopBattery && pms.hasPPD)
      ppdProcess.running = true;
  }

  Component.onCompleted: pms.refreshPowerInfo()
  Component.onDestruction: {
    brightnessDebounce.stop();
    brightnessProcess.running = false;
    ppdProcess.running = false;
    try {
      brightnessProcess.destroy();
    } catch (_) {}
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

  // Listen to BatteryService property changes to refresh power info when battery state changes
  Connections {
    function onDisplayDeviceChanged() {
      pms.refreshPowerInfo();
    }
    function onIsLaptopBatteryChanged() {
      pms.refreshPowerInfo();
    }
    function onIsOnBatteryChanged() {
      pms.refreshPowerInfo();
    }

    target: BatteryService
  }

  // Brightness control process + debounce
  Process {
    id: brightnessProcess

    command: []
    running: false
  }
  Timer {
    id: brightnessDebounce

    interval: 250
    repeat: false

    onTriggered: {
      if (!BatteryService.isLaptopBattery)
        return;
      brightnessProcess.running = true;
    }
  }
  // Debounce timer for refreshPowerInfo to avoid rapid repeated spawns
  Timer {
    id: _refreshDebounce
    interval: 80
    repeat: false
    onTriggered: _doRefreshPowerInfo()
    onTriggered: pms._doRefreshPowerInfo()
  }
  Component {
    id: readProcessComponent

    Process {
      running: false

      stdout: StdioCollector {}
    }
  }
  Process {
    id: ppdProcess

    command: ["powerprofilesctl", "get"]
    running: false

    stdout: StdioCollector {
      id: ppdStdout

      onStreamFinished: {
        pms.ppdText = (ppdStdout.text ? ppdStdout.text.trim() : "") || "Unknown";
        pms.powerInfoUpdated();
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
        const text = (ppdCheckStdout.text || "").trim();
        pms.hasPPD = (text === "yes");
        // re-evaluate whether we should start ppdProcess
        if (pms.hasPPD && BatteryService.isLaptopBattery)
          ppdProcess.running = true;
      }
    }
  }
}
