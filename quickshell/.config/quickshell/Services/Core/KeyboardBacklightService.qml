pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils
import qs.Services

Singleton {
  id: root

  readonly property bool available: MainService.hasKeyboardBacklight
  property string devicePath: ""
  property string deviceName: ""
  property int brightness: 0
  property int maxBrightness: 3
  readonly property int level: brightness
  readonly property string levelName: {
    if (brightness === 0)
      return "Off";
    if (maxBrightness === 3) {
      if (brightness === 1)
        return "Low";
      if (brightness === 2)
        return "Medium";
      if (brightness === 3)
        return "High";
    }
    return `Level ${brightness}`;
  }
  property bool ready: false
  property int lastBrightness: -1

  function setLevel(level) {
    if (!available || !deviceName)
      return "Keyboard backlight not available";
    const clamped = Math.max(0, Math.min(maxBrightness, level));
    setBrightnessProcess.command = ["brightnessctl", `--device=${deviceName}`, "set", `${clamped}`];
    setBrightnessProcess.running = true;
    return `Keyboard backlight set to ${levelName}`;
  }

  function increase() {
    setLevel(Math.min(maxBrightness, brightness + 1));
  }

  function decrease() {
    setLevel(Math.max(0, brightness - 1));
  }

  function refresh() {
    monitorProcess.running = false;
    monitorProcess.running = true;
  }

  // Detect keyboard backlight device
  Process {
    id: deviceDetector
    command: ["sh", "-c", "ls -1 /sys/class/leds/*kbd_backlight*/brightness 2>/dev/null | head -1 | sed 's|/brightness||'"]
    running: root.available

    stdout: StdioCollector {
      onStreamFinished: {
        const fullPath = text.trim();
        Logger.log("KeyboardBacklightService", `Device detector found: "${fullPath}"`);
        if (fullPath) {
          root.devicePath = fullPath;
          // Extract device name from path: /sys/class/leds/asus::kbd_backlight -> asus::kbd_backlight
          const parts = fullPath.split('/');
          root.deviceName = parts[parts.length - 1];
          Logger.log("KeyboardBacklightService", `Device name extracted: ${root.deviceName}`);
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
      Logger.log("KeyboardBacklightService", `Max brightness loaded: ${value}`);
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

  Component.onCompleted: {
    if (available) {
      Logger.log("KeyboardBacklightService", `initializing...`);
    } else {
      Logger.log("KeyboardBacklightService", "not available");
    }
  }

  onDevicePathChanged: {
    if (devicePath) {
      root.ready = true;
      Logger.log("KeyboardBacklightService", `ready | device: ${deviceName} (${devicePath}) | level: ${brightness}/${maxBrightness} (${levelName})`);
    }
  }

  onBrightnessChanged: {
    if (available && ready) {
      Logger.log("KeyboardBacklightService", `keyboard backlight: ${brightness}/${maxBrightness} (${levelName})`);
    }
  }
}
