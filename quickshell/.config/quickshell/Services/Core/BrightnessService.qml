pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils
import qs.Services

Singleton {
  id: root

  readonly property bool available: MainService.hasBrightnessControl
  property int brightness: 0
  property string devicePath: ""
  property int lastBrightness: -1
  property int maxBrightness: 100
  readonly property int percentage: maxBrightness > 0 ? Math.round((brightness / maxBrightness) * 100) : 0
  property bool ready: false
  readonly property int step: 5

  function decrease() {
    setBrightness(Math.max(1, percentage - step));
  }

  function increase() {
    setBrightness(percentage + step);
  }

  function refresh() {
    monitorProcess.running = false;
    monitorProcess.running = true;
  }

  function setBrightness(percent) {
    if (!available)
      return "Brightness control not available";
    const clamped = Math.max(0, Math.min(100, percent));
    setBrightnessProcess.command = ["brightnessctl", "--class=backlight", "set", `${clamped}%`];
    setBrightnessProcess.running = true;
    return `Brightness set to ${clamped}%`;
  }

  Component.onCompleted: {
    if (available) {
      Logger.log("BrightnessService", `initializing...`);
    } else {
      Logger.log("BrightnessService", "not available");
    }
  }
  onDevicePathChanged: {
    if (devicePath) {
      root.ready = true;
      Logger.log("BrightnessService", `ready | device: ${devicePath} | brightness: ${percentage}%`);
    }
  }
  onPercentageChanged: {
    if (available && ready) {
      Logger.log("BrightnessService", `brightness: ${percentage}%`);
    }
  }

  // Detect backlight device
  Process {
    id: deviceDetector

    command: ["sh", "-c", "ls /sys/class/backlight/ 2>/dev/null | head -1"]
    running: root.available

    stdout: StdioCollector {
      onStreamFinished: {
        const device = text.trim();
        if (device) {
          root.devicePath = `/sys/class/backlight/${device}`;
        }
      }
    }
  }

  // Watch brightness file with polling (sysfs doesn't support inotify well)
  Process {
    id: monitorProcess

    command: ["sh", "-c", `
      path="${root.devicePath}/brightness"
      while :; do
        if [ -f "$path" ]; then
          cat "$path" 2>/dev/null || echo "0"
        else
          echo "0"
        fi
        sleep 0.2
      done
    `]
    running: root.available && root.devicePath !== ""

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: line => {
        const value = Number.parseInt(line.trim(), 10);
        if (!Number.isNaN(value) && value !== root.lastBrightness) {
          root.lastBrightness = value;
          root.brightness = value;
        }
      }
    }
  }

  // Read max brightness once
  FileView {
    id: maxBrightnessFile

    path: root.devicePath ? `${root.devicePath}/max_brightness` : ""

    onLoaded: {
      const value = Number.parseInt(text().trim(), 10);
      if (!Number.isNaN(value)) {
        root.maxBrightness = value;
      }
    }
  }

  Process {
    id: setBrightnessProcess

    stdout: SplitParser {
      onRead: () => {
      // Monitor process will pick up the change
      }
    }
  }
}
