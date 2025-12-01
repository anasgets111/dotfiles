pragma ComponentBehavior: Bound

import QtQuick
import qs.Services
import qs.Services.Core
import qs.Services.Utils
import qs.Components
import qs.Config

Row {
  id: leftSide

  required property bool normalWorkspacesExpanded

  signal wallpaperPickerRequested

  spacing: 8

  Loader {
    active: true
    anchors.verticalCenter: parent.verticalCenter

    sourceComponent: PowerMenu {
    }
  }

  Loader {
    active: MainService.isArchBased
    anchors.verticalCenter: parent.verticalCenter

    sourceComponent: ArchChecker {
    }
  }

  IdleInhibitor {
    id: idleInhibitor

    anchors.verticalCenter: leftSide.verticalCenter
  }

  KeyboardLayoutIndicator {
    anchors.verticalCenter: leftSide.verticalCenter
  }

  Loader {
    active: BatteryService.isLaptopBattery

    sourceComponent: BatteryIndicator {
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  IconButton {
    id: launcherButton

    anchors.verticalCenter: parent.verticalCenter
    colorBg: Theme.inactiveColor
    icon: "󰍜"
    tooltipText: qsTr("Open application launcher")

    onClicked: IPC.launcherActive = !IPC.launcherActive
  }

  WallpaperButton {
    id: wallpaperButton

    anchors.verticalCenter: parent.verticalCenter
    tooltipText: qsTr("Open wallpaper picker / right-click randomize")

    onPickerRequested: leftSide.wallpaperPickerRequested()
  }

  Loader {
    id: niriWsLoader

    active: MainService.currentWM === "niri"

    sourceComponent: NiriWorkspaces {
      anchors.verticalCenter: parent.verticalCenter
    }

    onItemChanged: if (item)
      leftSide.normalWorkspacesExpanded = Qt.binding(() => item.expanded)
  }

  Loader {
    active: MainService.currentWM === "hyprland"

    sourceComponent: SpecialWorkspaces {
      id: specialWorkspaces

      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Loader {
    id: normalWsLoader

    active: MainService.currentWM === "hyprland"

    sourceComponent: NormalWorkspaces {
      anchors.verticalCenter: parent.verticalCenter
    }

    onItemChanged: if (item)
      leftSide.normalWorkspacesExpanded = Qt.binding(() => item.expanded)
  }
}
