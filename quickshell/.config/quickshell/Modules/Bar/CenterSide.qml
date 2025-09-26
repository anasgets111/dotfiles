pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Components
import qs.Services.Utils

Row {
  id: centerSide

  required property bool normalWorkspacesExpanded
  signal wallpaperPickerRequested

  spacing: 8

  IconButton {
    id: launcherButton

    anchors.verticalCenter: parent.verticalCenter
    colorBg: Theme.inactiveColor
    icon: "󰍉"
    tooltipText: qsTr("Open application launcher")

    onClicked: IPC.launcherActive = !IPC.launcherActive
  }

  // Active window title display
  ActiveWindow {
    id: activeWindowTitle
    anchors.verticalCenter: parent.verticalCenter
    visible: true
  }

  WallpaperButton {
    id: wallpaperButton
    anchors.verticalCenter: parent.verticalCenter
    tooltipText: qsTr("Open wallpaper picker / right-click randomize")
    onPickerRequested: centerSide.wallpaperPickerRequested()
  }
}
