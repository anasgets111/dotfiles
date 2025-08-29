pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Config
import qs.Services.WM
import qs.Widgets

Item {
  id: normalWorkspaces

  readonly property var backingWorkspaces: WorkspaceService.workspaces
  property int currentWorkspace: WorkspaceService.currentWorkspace > 0 ? WorkspaceService.currentWorkspace : 1
  property bool expanded: false
  property int hoveredIndex: 0
  readonly property bool isHyprlandSession: (Quickshell.env && (Quickshell.env("XDG_SESSION_DESKTOP") === "Hyprland" || Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland" || Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")))
  property int slideFrom: normalWorkspaces.currentWorkspace
  property real slideProgress: 0
  property int slideTo: normalWorkspaces.currentWorkspace
  readonly property var slots: Array(10).fill(0).map((_, i) => i + 1)

  function wsColor(id) {
    if (id === currentWorkspace)
      return Theme.activeColor;
    const exists = !!backingWorkspaces.find(w => w.id === id);
    if (id === hoveredIndex)
      return Theme.onHoverColor;
    return exists ? Theme.inactiveColor : Theme.disabledColor;
  }

  clip: true
  height: Theme.itemHeight
  visible: isHyprlandSession
  width: expanded ? workspacesRow.fullWidth : Theme.itemWidth

  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  Connections {
    function onCurrentWorkspaceChanged() {
      normalWorkspaces.slideFrom = normalWorkspaces.currentWorkspace;
      normalWorkspaces.currentWorkspace = WorkspaceService.currentWorkspace > 0 ? WorkspaceService.currentWorkspace : 1;
      normalWorkspaces.slideTo = normalWorkspaces.currentWorkspace;
      slideAnim.restart();
    }

    target: WorkspaceService
  }
  NumberAnimation {
    id: slideAnim

    duration: Theme.animationDuration
    from: 0
    property: "slideProgress"
    target: normalWorkspaces
    to: 1
  }
  Timer {
    id: collapseTimer

    interval: Theme.animationDuration + 200

    onTriggered: {
      normalWorkspaces.expanded = false;
      normalWorkspaces.hoveredIndex = 0;
    }
  }

  // Hover fence only when collapsed to trigger expansion
  MouseArea {
    acceptedButtons: Qt.NoButton
    anchors.fill: parent
    hoverEnabled: true
    visible: !normalWorkspaces.expanded

    onEntered: {
      normalWorkspaces.expanded = true;
      collapseTimer.stop();
    }
    onExited: collapseTimer.restart()
  }
  Item {
    id: workspacesRow

    readonly property int count: 10
    readonly property int fullWidth: count * Theme.itemWidth + Math.max(0, count - 1) * spacing
    property int spacing: 8

    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    height: Theme.itemHeight
    width: fullWidth

    Repeater {
      model: normalWorkspaces.slots

      delegate: IconButton {
        id: wsBtn

        readonly property int idNum: modelData
        required property int index     // 0-based
        required property int modelData // 1..10

        readonly property real slotX: (index) * (Theme.itemWidth + workspacesRow.spacing)

        bgColor: normalWorkspaces.wsColor(idNum)
        height: Theme.itemHeight
        iconText: "" + idNum
        opacity: (!!normalWorkspaces.backingWorkspaces.find(w => w.id === idNum)) ? 1 : 0.5
        width: Theme.itemWidth

        // stacked when collapsed; spread when expanded
        x: normalWorkspaces.expanded ? slotX : 0

        Behavior on x {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }

        onEntered: {
          normalWorkspaces.expanded = true;
          collapseTimer.stop();
          normalWorkspaces.hoveredIndex = wsBtn.idNum;
        }
        onExited: {
          if (normalWorkspaces.hoveredIndex === idNum)
            normalWorkspaces.hoveredIndex = 0;
          collapseTimer.restart();
        }
        onLeftClicked: {
          if (idNum !== normalWorkspaces.currentWorkspace)
            WorkspaceService.focusWorkspaceByIndex(idNum);
        }
      }
    }
  }
  Rectangle {
    id: collapsedWs

    readonly property int slideDirection: normalWorkspaces.slideTo === normalWorkspaces.slideFrom ? -1 : (normalWorkspaces.slideTo > normalWorkspaces.slideFrom ? -1 : 1)

    clip: true
    color: Theme.bgColor
    height: Theme.itemHeight
    radius: Theme.itemRadius
    visible: !normalWorkspaces.expanded
    width: Theme.itemWidth
    z: 1

    // From
    Rectangle {
      color: normalWorkspaces.wsColor(normalWorkspaces.slideFrom)
      height: Theme.itemHeight
      radius: Theme.itemRadius
      visible: normalWorkspaces.slideProgress < 1
      width: Theme.itemWidth
      x: normalWorkspaces.slideProgress * collapsedWs.slideDirection * Theme.itemWidth

      Text {
        anchors.centerIn: parent
        color: Theme.textContrast(parent.color)
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: normalWorkspaces.slideFrom
      }
    }

    // To
    Rectangle {
      color: normalWorkspaces.wsColor(normalWorkspaces.slideTo)
      height: Theme.itemHeight
      radius: Theme.itemRadius
      width: Theme.itemWidth
      x: (normalWorkspaces.slideProgress - 1) * collapsedWs.slideDirection * Theme.itemWidth

      Text {
        anchors.centerIn: parent
        color: Theme.textContrast(parent.color)
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: normalWorkspaces.slideTo
      }
    }
  }
}
