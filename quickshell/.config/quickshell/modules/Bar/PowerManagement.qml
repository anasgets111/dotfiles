pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
  id: root

  property string cpuGovernor: "Unknown"
  property string energyPerformance: "Unknown"
  property string kbdDevice: "asus::kbd_backlight"
  property int kbdOnAC: 3
  property int kbdOnBattery: 1
  property int onACBrightness: 100
  property bool onBattery: UPower.onBattery

  // Tunables
  property int onBatteryBrightness: 10
  readonly property string platformInfo: "Platform: " + root.platformProfile
  property string platformProfile: "Loading..."
  readonly property string ppdInfo: "PPD: " + root.ppdText
  property string ppdText: "Loading..."

  signal powerInfoUpdated
  signal thermalInfoUpdated

  function adjustBrightness() {
    if (!DetectEnv.isLaptopBattery)
      return;

    const screen = root.onBattery ? root.onBatteryBrightness : root.onACBrightness;
    const kbd = root.onBattery ? root.kbdOnBattery : root.kbdOnAC;
    const cmd = "brightnessctl set " + screen + "% && brightnessctl -d " + root.kbdDevice + " set " + kbd;

    brightnessProcess.command = ["sh", "-c", cmd];
    if (brightnessDebounce.running)
      brightnessDebounce.restart();
    else
      brightnessDebounce.start();
  }

  // Minimal one-shot reader utility (avoids implicit this/try/catch)
  function readFile(path, cb) {
    const p = readProcessComponent.createObject(root, {
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
    // Platform profile
    root.readFile("/sys/firmware/acpi/platform_profile", function (data) {
      root.platformProfile = data;
      root.powerInfoUpdated();
    });

    // CPU governor
    root.readFile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", function (data) {
      root.cpuGovernor = data;
      root.thermalInfoUpdated();
    });

    // EPP
    root.readFile("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference", function (data) {
      root.energyPerformance = data;
      root.thermalInfoUpdated();
    });

    if (DetectEnv.isLaptopBattery && DetectEnv.batteryManager === "ppd") {
      ppdProcess.running = true;
    }
  }

  Component.onCompleted: root.refreshPowerInfo()
  Component.onDestruction: {
    brightnessDebounce.stop();
    brightnessProcess.running = false;
    ppdProcess.running = false;
  }
  onOnBatteryChanged: {
    root.refreshPowerInfo();
    root.adjustBrightness();
  }

  Connections {
    function onBatteryManagerChanged() {
      root.refreshPowerInfo();
    }

    target: DetectEnv
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
      if (!DetectEnv.isLaptopBattery)
        return;
      brightnessProcess.running = true;
    }
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
        root.ppdText = (ppdStdout.text ? ppdStdout.text.trim() : "") || "Unknown";
        root.powerInfoUpdated();
      }
    }
  }
}
