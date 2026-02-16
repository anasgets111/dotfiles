pragma ComponentBehavior: Bound

import QtQuick
import qs.Services
import qs.Services.Core
import qs.Services.Utils
import qs.Components
import qs.Config
import qs.Modules.Bar.Indicators
import qs.Modules.Bar.Panels

Row {
  id: leftSide

  required property bool normalWorkspacesExpanded
  required property string screenName

  signal wallpaperPickerRequested

  spacing: Theme.spacingSm

  Loader {
    anchors.verticalCenter: parent.verticalCenter
    asynchronous: true

    sourceComponent: PowerMenu {
    }
  }

  Loader {
    active: MainService.isArchBased
    anchors.verticalCenter: parent.verticalCenter
    asynchronous: true

    sourceComponent: ArchChecker {
      screenName: leftSide.screenName
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
    asynchronous: true

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
    asynchronous: true

    sourceComponent: NiriWorkspaces {
      anchors.verticalCenter: parent.verticalCenter
    }

    onItemChanged: {
      const workspaces = item as NiriWorkspaces;
      if (workspaces)
        leftSide.normalWorkspacesExpanded = Qt.binding(() => workspaces.expanded);
    }
  }

  Loader {
    active: MainService.currentWM === "hyprland"
    asynchronous: true

    sourceComponent: SpecialWorkspaces {
      id: specialWorkspaces

      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Loader {
    id: normalWsLoader

    active: MainService.currentWM === "hyprland"
    asynchronous: true

    sourceComponent: NormalWorkspaces {
      anchors.verticalCenter: parent.verticalCenter
    }

    onItemChanged: {
      const workspaces = item as NormalWorkspaces;
      if (workspaces)
        leftSide.normalWorkspacesExpanded = Qt.binding(() => workspaces.expanded);
    }
  }
}
