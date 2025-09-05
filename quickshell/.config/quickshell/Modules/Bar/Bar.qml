import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Services.WM

PanelWindow {
  id: panelWindow

  property int _commitNudge: 0
  property bool _hadScreen: screen !== null
  property bool normalWorkspacesExpanded: false

  WlrLayershell.namespace: "quickshell:bar"
  color: "transparent"
  exclusiveZone: Theme.panelHeight
  screen: MonitorService.activeMainScreen
  visible: screen !== null

  mask: Region {
    item: panelRect
  }

  onScreenChanged: {
    const nowHasScreen = screen !== null;
    if (nowHasScreen && !_hadScreen) {
      _commitNudge = _commitNudge + 1;
    }
    _hadScreen = nowHasScreen;
  }

  anchors {
    left: true
    right: true
    top: true
  }
  Rectangle {
    id: panelRect

    color: Theme.bgColor
    height: Theme.panelHeight

    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
    }
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
  CenterSide {
    anchors.centerIn: panelRect
    normalWorkspacesExpanded: panelWindow.normalWorkspacesExpanded
  }
  RightSide {
    anchors {
      right: panelRect.right
      rightMargin: Theme.panelMargin
      verticalCenter: panelRect.verticalCenter
    }
  }
  Item {
    id: bottomCuts

    height: Theme.panelRadius

    anchors {
      left: parent.left
      right: parent.right
      top: panelRect.bottom
    }
    RoundCorner {
      id: bottomLeftCut

      color: Theme.bgColor
      orientation: 0 // TOP_LEFT
      radius: Theme.panelRadius

      anchors {
        left: parent.left
        top: parent.top
      }
    }
    RoundCorner {
      id: bottomRightCut

      color: Theme.bgColor
      orientation: 1 // TOP_RIGHT
      radius: Theme.panelRadius

      anchors {
        right: parent.right
        top: parent.top
      }
    }
  }
}
