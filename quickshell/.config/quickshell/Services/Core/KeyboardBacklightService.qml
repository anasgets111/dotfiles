pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.Services.Utils
import qs.Services

Singleton {
  id: root

  readonly property string _deviceName: _devicePath ? _devicePath.split("/").pop() : ""
  readonly property string _devicePath: {
    for (let i = 0; i < ledsFolder.count; i++) {
      const name = ledsFolder.get(i, "fileName");
      if (name.includes("kbd_backlight"))
        return `/sys/class/leds/${name}`;
    }
    return "";
  }
  readonly property bool available: MainService.hasKeyboardBacklight
  property int brightness: 0
  readonly property string levelName: ["Off", "Low", "Medium", "High"][brightness] ?? `Level ${brightness}`
  property int maxBrightness: 3
  property bool ready: false

  function decrease() {
    setLevel(Math.max(0, brightness - 1));
  }

  function increase() {
    setLevel(Math.min(maxBrightness, brightness + 1));
  }

  function setLevel(level) {
    if (!available || !_deviceName)
      return "Keyboard backlight not available";
    const clamped = Math.max(0, Math.min(maxBrightness, level));
    setBrightnessProcess.command = ["brightnessctl", `--device=${_deviceName}`, "set", `${clamped}`];
    setBrightnessProcess.running = true;
    return `Keyboard backlight set to ${levelName}`;
  }

  onAvailableChanged: {
    if (!available)
      Logger.log("KeyboardBacklightService", "not available");
  }
  onBrightnessChanged: {
    if (available && ready)
      Logger.log("KeyboardBacklightService", `keyboard backlight: ${brightness}/${maxBrightness} (${levelName})`);
  }
  on_DevicePathChanged: {
    if (_devicePath) {
      root.ready = true;
      Logger.log("KeyboardBacklightService", `ready | device: ${_deviceName} (${_devicePath}) | level: ${brightness}/${maxBrightness} (${levelName})`);
    }
  }

  FolderListModel {
    id: ledsFolder

    folder: "file:///sys/class/leds"
    showDirs: true
    showFiles: false
  }

  FileView {
    id: maxBrightnessFile

    path: root._devicePath ? `${root._devicePath}/max_brightness` : ""

    onLoaded: root.maxBrightness = parseInt(text().trim(), 10) || 3
  }

  FileView {
    id: brightnessFile

    path: root._devicePath ? `${root._devicePath}/brightness` : ""

    onLoaded: root.brightness = parseInt(text().trim(), 10) || 0
  }

  Timer {
    interval: 100
    repeat: true
    running: root.available && root._devicePath !== ""

    onTriggered: brightnessFile.reload()
  }

  Process {
    id: setBrightnessProcess

  }
}
