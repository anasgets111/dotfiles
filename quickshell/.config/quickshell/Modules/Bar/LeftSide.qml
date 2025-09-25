pragma ComponentBehavior: Bound

import QtQuick
import qs.Services
import qs.Services.Core

Row {
  id: leftSide

  required property bool normalWorkspacesExpanded

  spacing: 8

  Loader {
    anchors.verticalCenter: parent.verticalCenter
    active: true
    sourceComponent: PowerMenu {}
  }
  Loader {
    anchors.verticalCenter: parent.verticalCenter
    active: MainService.isArchBased

    sourceComponent: ArchChecker {}
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
  Loader {
    active: MainService.currentWM === "niri"

    sourceComponent: NiriWorkspaces {
      id: niriWorkspaces

      anchors.verticalCenter: parent.verticalCenter
      expanded: leftSide.normalWorkspacesExpanded

      onExpandedChanged: leftSide.normalWorkspacesExpanded = expanded
    }
  }
  Loader {
    active: MainService.currentWM === "hyprland"

    sourceComponent: SpecialWorkspaces {
      id: specialWorkspaces

      anchors.verticalCenter: parent.verticalCenter
    }
  }
  Loader {
    active: MainService.currentWM === "hyprland"

    sourceComponent: NormalWorkspaces {
      id: normalWorkspaces

      anchors.verticalCenter: parent.verticalCenter
      expanded: leftSide.normalWorkspacesExpanded

      onExpandedChanged: leftSide.normalWorkspacesExpanded = expanded
    }
  }
}
