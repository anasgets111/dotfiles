import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Components
import qs.Config
import qs.Services.WM

PanelWindow {
  id: panelWindow

  property bool _screenChangeGuard: false
  readonly property bool centerShouldHide: workspacesExpanded || rightSideExpanded
  property bool rightSideExpanded: false
  property bool workspacesExpanded: false

  signal wallpaperPickerRequested

  WlrLayershell.namespace: "quickshell:bar:blur"
  color: Theme.panelWindowColor
  exclusiveZone: Theme.panelHeight
  implicitHeight: panelWindow.screen.height
  screen: MonitorService.effectiveMainScreen
  surfaceFormat.opaque: false

  mask: Region {
    item: panelRect
  }

  onScreenChanged: {
    if (_screenChangeGuard)
      return;
    _screenChangeGuard = true;
    if (!visible)
      visible = true;
    _screenChangeGuard = false;
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

    LeftSide {
      normalWorkspacesExpanded: panelWindow.workspacesExpanded

      onNormalWorkspacesExpandedChanged: panelWindow.workspacesExpanded = normalWorkspacesExpanded
      onWallpaperPickerRequested: panelWindow.wallpaperPickerRequested()

      anchors {
        left: panelRect.left
        leftMargin: Theme.panelMargin
        verticalCenter: panelRect.verticalCenter
      }
    }

    RightSide {
      normalWorkspacesExpanded: panelWindow.rightSideExpanded

      onNormalWorkspacesExpandedChanged: panelWindow.rightSideExpanded = normalWorkspacesExpanded

      anchors {
        right: panelRect.right
        rightMargin: Theme.panelMargin
        verticalCenter: panelRect.verticalCenter
      }
    }

    CenterSide {
      anchors.centerIn: panelRect
      normalWorkspacesExpanded: panelWindow.centerShouldHide
      // When workspaces (or volume) are expanded, hide center via opacity
      opacity: panelWindow.centerShouldHide ? 0 : 1

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }
    }
  }

  Item {
    id: bottomCuts

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: panelRect.bottom
    height: Theme.panelRadius
    width: parent.width

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
