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
  implicitHeight: screen ? screen.height : Theme.panelHeight
  screen: MonitorService.effectiveMainScreen
  surfaceFormat.opaque: false

  mask: Region {
    item: barContent
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

  Column {
    id: barContent

    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
    }

    Rectangle {
      id: panelRect

      color: Theme.bgColor
      height: Theme.panelHeight
      width: parent.width

      LeftSide {
        normalWorkspacesExpanded: panelWindow.workspacesExpanded

        onNormalWorkspacesExpandedChanged: panelWindow.workspacesExpanded = normalWorkspacesExpanded
        onWallpaperPickerRequested: panelWindow.wallpaperPickerRequested()

        anchors {
          left: parent.left
          leftMargin: Theme.panelMargin
          verticalCenter: parent.verticalCenter
        }
      }

      RightSide {
        normalWorkspacesExpanded: panelWindow.rightSideExpanded

        onNormalWorkspacesExpandedChanged: panelWindow.rightSideExpanded = normalWorkspacesExpanded

        anchors {
          right: parent.right
          rightMargin: Theme.panelMargin
          verticalCenter: parent.verticalCenter
        }
      }

      CenterSide {
        anchors.centerIn: parent
        normalWorkspacesExpanded: panelWindow.centerShouldHide
        opacity: panelWindow.centerShouldHide ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }
      }
    }

    Item {
      height: Theme.panelRadius
      width: parent.width

      RoundCorner {
        color: Theme.bgColor
        height: radius
        radius: Theme.panelRadius
        width: radius
      }

      RoundCorner {
        anchors.right: parent.right
        color: Theme.bgColor
        height: radius
        orientation: 1
        radius: Theme.panelRadius
        width: radius
      }
    }
  }
}
