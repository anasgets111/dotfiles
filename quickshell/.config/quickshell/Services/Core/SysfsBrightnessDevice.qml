pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel

Item {
  id: root

  property string directory: ""
  property int maxBrightnessFallback: 100
  property string nameIncludes: ""
  readonly property bool available: devicePath !== ""
  readonly property int brightness: brightnessFile.value
  readonly property string deviceName: devicePath ? devicePath.split("/").pop() : ""
  readonly property string devicePath: {
    for (let index = 0; index < deviceFolder.count; index++) {
      const fileName = deviceFolder.get(index, "fileName");
      if (!nameIncludes || fileName.includes(nameIncludes))
        return `${directory}/${fileName}`;
    }
    return "";
  }
  readonly property string folderUrl: directory ? `file://${directory}` : ""
  readonly property int maxBrightness: maxBrightnessFile.value
  readonly property bool ready: available && brightnessFile.valid && maxBrightnessFile.valid

  function rescan(): void {
    if (!devicePath)
      return;
    deviceFolder.folder = "";
    folderReset.restart();
  }

  FolderListModel {
    id: deviceFolder

    folder: root.folderUrl
    showDirs: true
    showFiles: false
  }
  SysfsValue {
    id: maxBrightnessFile

    fallback: root.maxBrightnessFallback
    path: root.devicePath ? `${root.devicePath}/max_brightness` : ""

    onReadFailed: root.rescan()
  }
  SysfsValue {
    id: brightnessFile

    path: root.devicePath ? `${root.devicePath}/brightness` : ""

    onReadFailed: root.rescan()
  }
  Timer {
    id: folderReset

    interval: 100

    onTriggered: {
      deviceFolder.folder = root.folderUrl;
    }
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
