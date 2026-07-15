pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.Services.Utils

Singleton {
  id: root

  readonly property string _devicePath: backlightFolder.count ? `/sys/class/backlight/${backlightFolder.get(0, "fileName")}` : ""
  readonly property bool available: _devicePath !== ""
  readonly property int brightness: brightnessFile.value
  readonly property int maxBrightness: maxBrightnessFile.value
  readonly property int percentage: maxBrightness > 0 ? Math.round((brightness / maxBrightness) * 100) : 0
  readonly property bool ready: available && brightnessFile.valid && maxBrightnessFile.valid
  readonly property int step: 5

  function decrease() {
    setBrightness(Math.max(1, percentage - step));
  }
  function increase() {
    setBrightness(percentage + step);
  }
  function setBrightness(percent: real): string {
    if (!available)
      return "Brightness control not available";
    const clamped = Math.max(0, Math.min(100, percent));
    Command.run(["brightnessctl", "--class=backlight", "set", `${clamped}%`]);
    return `Brightness set to ${clamped}%`;
  }

  onAvailableChanged: {
    if (!available)
      Logger.log("BrightnessService", "not available");
  }
  onPercentageChanged: {
    if (available && ready)
      Logger.log("BrightnessService", `brightness: ${percentage}%`);
  }
  onReadyChanged: {
    if (ready)
      Logger.log("BrightnessService", `ready | device: ${_devicePath} | brightness: ${percentage}%`);
  }
  on_DevicePathChanged: {
    if (!_devicePath)
      Logger.log("BrightnessService", "device lost");
  }

  FolderListModel {
    id: backlightFolder

    folder: "file:///sys/class/backlight"
    showDirs: true
    showFiles: false
  }
  SysfsValue {
    id: maxBrightnessFile

    fallback: 100
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
