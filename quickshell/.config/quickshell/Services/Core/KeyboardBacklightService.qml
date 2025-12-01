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

  Process {
    id: monitorProcess

    command: ["sh", "-c", `
      path=$(ls -1d /sys/class/leds/*kbd_backlight* 2>/dev/null | head -1)
      [ -z "$path" ] && exit 1
      name=$(basename "$path")
      echo "INIT $path $name $(cat "$path/max_brightness" 2>/dev/null)"
      last=""
      while read -r _; do
        cur=$(cat "$path/brightness" 2>/dev/null)
        [ "$cur" != "$last" ] && echo "$cur" && last="$cur"
      done
    `]
    running: root.available

    stdout: SplitParser {
      onRead: line => {
        const trimmed = line.trim();
        if (trimmed.startsWith("INIT ")) {
          const parts = trimmed.split(" ");
          root.devicePath = parts[1];
          root.deviceName = parts[2];
          root.maxBrightness = Number.parseInt(parts[3], 10) || 3;
          return;
        }
        const value = Number.parseInt(trimmed, 10);
        if (!Number.isNaN(value) && value !== root.brightness) {
          root.brightness = value;
        }
      }
    }

    onRunningChanged: if (!running && root.available)
      restartTimer.start()
  }

  Timer {
    interval: 100
    repeat: true
    running: monitorProcess.running

    onTriggered: monitorProcess.write("\n")
  }

  Timer {
    id: restartTimer

    interval: 1000

    onTriggered: monitorProcess.running = true
  }

  Process {
    id: setBrightnessProcess

  }
}
