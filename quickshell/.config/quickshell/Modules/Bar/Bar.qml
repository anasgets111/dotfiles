import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Services.WM

PanelWindow {
  id: panelWindow

  property bool normalWorkspacesExpanded: false
  property bool screenChanging: false

  WlrLayershell.namespace: "quickshell:bar:blur"
  color: Theme.panelWindowColor
  exclusiveZone: Theme.panelHeight
  implicitHeight: panelWindow.screen ? panelWindow.screen.height : Theme.panelHeight
  screen: MonitorService.effectiveMainScreen
  visible: true

  mask: Region {
    item: panelRect
  }

  anchors {
    left: true
    right: true
    top: true
  }
  Rectangle {
    id: panelRect

    anchors.left: parent.left
    anchors.top: parent.top
    color: Theme.bgColor
    height: Theme.panelHeight
    width: parent.width
  }
  LeftSide {
    normalWorkspacesExpanded: panelWindow.normalWorkspacesExpanded

    onNormalWorkspacesExpandedChanged: panelWindow.normalWorkspacesExpanded = normalWorkspacesExpanded

    anchors {
      left: panelRect.left
      leftMargin: Theme.panelMargin
      verticalCenter: panelRect.verticalCenter
    }
  }
  RightSide {
    anchors {
      right: panelRect.right
      rightMargin: Theme.panelMargin
      verticalCenter: panelRect.verticalCenter
    }
  }
  CenterSide {
    anchors.centerIn: panelRect
    normalWorkspacesExpanded: panelWindow.normalWorkspacesExpanded
  }
  Item {
    id: bottomCuts

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: panelRect.bottom
    height: Theme.panelRadius
    width: parent.width

    // Round corners to cut into the panel background on the left/right
    RoundCorner {
      id: bottomLeftCut

      anchors.left: parent.left
      anchors.top: parent.top
      color: Theme.bgColor
      orientation: 0 // TOP_LEFT
      radius: Theme.panelRadius
    }
    RoundCorner {
      id: bottomRightCut

      anchors.right: parent.right
      anchors.top: parent.top
      color: Theme.bgColor
      orientation: 1 // TOP_RIGHT
      radius: Theme.panelRadius
    }
  }
}
