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

  readonly property string _devicePath: {
    for (let i = 0; i < backlightFolder.count; i++)
      return `/sys/class/backlight/${backlightFolder.get(i, "fileName")}`;
    return "";
  }
  readonly property bool available: MainService.hasBrightnessControl
  property int brightness: 0
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

  function setBrightness(percent) {
    if (!available)
      return "Brightness control not available";
    const clamped = Math.max(0, Math.min(100, percent));
    setBrightnessProcess.command = ["brightnessctl", "--class=backlight", "set", `${clamped}%`];
    setBrightnessProcess.running = true;
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
  on_DevicePathChanged: {
    if (_devicePath) {
      root.ready = true;
      Logger.log("BrightnessService", `ready | device: ${_devicePath} | brightness: ${percentage}%`);
    }
  }

  FolderListModel {
    id: backlightFolder

    folder: "file:///sys/class/backlight"
    showDirs: true
    showFiles: false
  }

  FileView {
    id: maxBrightnessFile

    path: root._devicePath ? `${root._devicePath}/max_brightness` : ""

    onLoaded: root.maxBrightness = parseInt(text().trim(), 10) || 100
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
