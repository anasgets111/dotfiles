pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils
import qs.Services

Singleton {
  id: root

  readonly property bool available: MainService.hasKeyboardBacklight
  property int brightness: 0
  property string deviceName: ""
  property string devicePath: ""
  readonly property string levelName: ["Off", "Low", "Medium", "High"][brightness] ?? `Level ${brightness}`
  property int maxBrightness: 3
  property bool ready: false

  function decrease() {
    setLevel(Math.max(0, brightness - 1));
  }

  function increase() {
    setLevel(Math.min(maxBrightness, brightness + 1));
  }

  function refresh() {
    monitorProcess.running = false;
    monitorProcess.running = true;
  }

  function setLevel(level) {
    if (!available || !deviceName)
      return "Keyboard backlight not available";
    const clamped = Math.max(0, Math.min(maxBrightness, level));
    setBrightnessProcess.command = ["brightnessctl", `--device=${deviceName}`, "set", `${clamped}`];
    setBrightnessProcess.running = true;
    return `Keyboard backlight set to ${levelName}`;
  }

  Component.onCompleted: {
    if (available) {
      Logger.log("KeyboardBacklightService", `initializing...`);
    } else {
      Logger.log("KeyboardBacklightService", "not available");
    }
  }
  onBrightnessChanged: {
    if (available && ready) {
      Logger.log("KeyboardBacklightService", `keyboard backlight: ${brightness}/${maxBrightness} (${levelName})`);
    }
  }
  onDevicePathChanged: {
    if (devicePath) {
      root.ready = true;
      Logger.log("KeyboardBacklightService", `ready | device: ${deviceName} (${devicePath}) | level: ${brightness}/${maxBrightness} (${levelName})`);
    }
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

    command: ["sh", "-c", `while :; do cat "${root.devicePath}/brightness" 2>/dev/null || echo 0; sleep 0.2; done`]
    running: root.available && root.devicePath !== ""

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: line => {
        const value = Number.parseInt(line.trim(), 10);
        if (!Number.isNaN(value) && value !== root.brightness) {
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
}
