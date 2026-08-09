pragma ComponentBehavior: Bound

import QtQuick
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.Utils
import qs.Services.WM
import qs.Components
import qs.Config
import qs.Modules.Bar.Indicators
import qs.Modules.Bar.Panels

Row {
  id: leftSide

  required property string screenName

  signal wallpaperPickerRequested

  spacing: Theme.spacingSm

  PowerMenu {
    anchors.verticalCenter: parent.verticalCenter
  }
  Loader {
    active: UpdateService.ready
    anchors.verticalCenter: parent.verticalCenter
    asynchronous: true

    sourceComponent: ArchChecker {
      screenName: leftSide.screenName
    }
  }
  IdleInhibitor {
    anchors.verticalCenter: parent.verticalCenter
    screenName: leftSide.screenName
  }
  KeyboardLayoutIndicator {
    anchors.verticalCenter: parent.verticalCenter
  }
  Loader {
    active: BatteryService.isLaptopBattery
    asynchronous: true

    sourceComponent: BatteryIndicator {
      anchors.verticalCenter: parent.verticalCenter
    }
  }
  IconButton {
    anchors.verticalCenter: parent.verticalCenter
    icon: "󰍜"
    tooltipText: qsTr("Open application launcher")

    onClicked: IPC.toggleLauncher()
  }
  WallpaperButton {
    anchors.verticalCenter: parent.verticalCenter
    tooltipText: qsTr("Open wallpaper picker / right-click randomize")

    onPickerRequested: leftSide.wallpaperPickerRequested()
  }
  Loader {
    active: WorkspaceService.supportsSpecialWorkspaces
    asynchronous: true

    sourceComponent: SpecialWorkspaces {
      anchors.verticalCenter: parent.verticalCenter
    }
  }
  Loader {
    active: WorkspaceService.ready
    asynchronous: true

    sourceComponent: WorkspaceStrip {
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
