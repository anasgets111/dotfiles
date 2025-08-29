import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config

PanelWindow {
  id: panelWindow

  property string mainMonitor: Quickshell.env("MAINMON")
  property bool normalWorkspacesExpanded: false

  WlrLayershell.namespace: "quickshell:bar:blur"
  color: Theme.panelWindowColor
  exclusiveZone: Theme.panelHeight
  implicitHeight: panelWindow.screen.height
  implicitWidth: panelWindow.screen.width
  screen: Quickshell.screens.length > 1 ? Quickshell.screens[1] : Quickshell.screens[0]

  mask: Region {
    item: panelRect
  }

  Item {
    id: screenBinder

    property int debounceRestarts: 0

    function pickScreen() {
      const screens = Quickshell.screens || [];
      const target = panelWindow.mainMonitor ? screens.find(s => s && (s.name === panelWindow.mainMonitor || s.model === panelWindow.mainMonitor)) : null;
      return target || screens[0];
    }

    Timer {
      id: screenDebounce

      interval: 500
      repeat: false

      onTriggered: {
        const sel = screenBinder.pickScreen();
        if (!sel || panelWindow.screen !== sel) {
          panelWindow.screen = sel;
        }
        postAssignCheck.restart();
      }
    }
    Timer {
      id: postAssignCheck

      interval: 160
      repeat: false

      onTriggered: {
        if (!panelWindow.visible && panelWindow.screen) {
          remapIfHidden.start();
        }
      }
    }
    Timer {
      id: remapIfHidden

      interval: 350
      repeat: false

      onTriggered: {
        if (!panelWindow.visible && panelWindow.screen) {
          panelWindow.visible = true;
        }
      }
    }
    Connections {
      function onScreensChanged() {
        screenDebounce.restart();
      }

      target: Quickshell
    }
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

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: panelRect.bottom
    height: Theme.panelRadius
    width: parent.width

    RoundCorner {
      anchors.left: parent.left
      anchors.top: parent.top
      color: Theme.bgColor
      corner: 2
      rotation: 90
      size: Theme.panelRadius
    }
    RoundCorner {
      anchors.right: parent.right
      anchors.top: parent.top
      color: Theme.bgColor
      corner: 3
      rotation: -90
      size: Theme.panelRadius
    }
  }
}
