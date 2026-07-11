pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.Services.Utils

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
  readonly property bool available: _devicePath !== ""
  readonly property int brightness: brightnessFile.value
  readonly property string levelName: ["Off", "Low", "Medium", "High"][brightness] ?? `Level ${brightness}`
  readonly property int maxBrightness: maxBrightnessFile.value
  readonly property bool ready: available && brightnessFile.valid && maxBrightnessFile.valid

  function decrease() {
    setLevel(Math.max(0, brightness - 1));
  }

  function increase() {
    setLevel(Math.min(maxBrightness, brightness + 1));
  }

  function setLevel(level: int): string {
    if (!available || !_deviceName)
      return "Keyboard backlight not available";
    const clamped = Math.max(0, Math.min(maxBrightness, level));
    Command.run(["brightnessctl", `--device=${_deviceName}`, "set", `${clamped}`]);
    const targetName = ["Off", "Low", "Medium", "High"][clamped] ?? `Level ${clamped}`;
    return `Keyboard backlight set to ${targetName}`;
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
    if (!_devicePath)
      Logger.log("KeyboardBacklightService", "device lost");
  }
  onReadyChanged: {
    if (ready)
      Logger.log("KeyboardBacklightService", `ready | device: ${_deviceName} (${_devicePath}) | level: ${brightness}/${maxBrightness} (${levelName})`);
  }

  FolderListModel {
    id: ledsFolder

    folder: "file:///sys/class/leds"
    showDirs: true
    showFiles: false
  }

  SysfsValue {
    id: maxBrightnessFile

    fallback: 3
    path: root._devicePath ? `${root._devicePath}/max_brightness` : ""
  }

  SysfsValue {
    id: brightnessFile

    path: root._devicePath ? `${root._devicePath}/brightness` : ""
  }

  Timer {
    interval: 100
    repeat: true
    running: root.available

    onTriggered: {
      if (!maxBrightnessFile.valid)
        maxBrightnessFile.reload();
      brightnessFile.reload();
    }
  }
}
