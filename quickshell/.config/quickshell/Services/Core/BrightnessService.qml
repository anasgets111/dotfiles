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

  Process {
    id: monitorProcess

    command: ["sh", "-c", `
      dev=$(ls /sys/class/backlight/ 2>/dev/null | head -1)
      [ -z "$dev" ] && exit 1
      path="/sys/class/backlight/$dev"
      echo "INIT $path $(cat "$path/max_brightness" 2>/dev/null)"
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
          root.maxBrightness = Number.parseInt(parts[2], 10) || 100;
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
