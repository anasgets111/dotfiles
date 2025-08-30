pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Services.WM
import qs.Widgets

Item {
  id: root

  readonly property int currentWs: Math.max(1, WorkspaceService.currentWorkspace)

  // UI state
  property bool expanded: false
  readonly property int focusedIndex: {
    // find index by ws.id or idx matching currentWs
    for (let i = 0; i < workspaces.length; i++) {
      const ws = workspaces[i];
      if (ws.id === currentWs || ws.idx === currentWs)
        return i;
    }
    return Math.max(0, Math.min(currentWs - 1, workspaces.length - 1));
  }
  readonly property int fullWidth: workspaces.length * slotW + Math.max(0, workspaces.length - 1) * spacing
  readonly property var groupBoundaries: WorkspaceService.groupBoundaries
  property int hoveredId: 0
  readonly property int slotH: Theme.itemHeight
  readonly property int slotW: Theme.itemWidth

  // Layout
  readonly property int spacing: 8

  // Slide the row so the focused slot is visible when collapsed
  // and aligned left when expanded
  readonly property int targetRowX: expanded ? 0 : -(focusedIndex * (slotW + spacing))

  // Service state
  readonly property var workspaces: WorkspaceService.workspaces

  function wsColor(ws) {
    if (!ws)
      return Theme.disabledColor;
    if (ws.is_focused || ws.idx === currentWs)
      return Theme.activeColor;
    if (ws.id === hoveredId)
      return Theme.onHoverColor;
    return ws.populated ? Theme.inactiveColor : Theme.disabledColor;
  }

  clip: true
  height: slotH
  width: expanded ? fullWidth : slotW

  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  // Hover expand/collapse
  Timer {
    id: collapseTimer

    interval: Theme.animationDuration + 200

    onTriggered: {
      root.expanded = false;
      root.hoveredId = 0;
    }
  }
  HoverHandler {
    onHoveredChanged: hovered ? (root.expanded = true, collapseTimer.stop()) : collapseTimer.restart()
  }
  Item {
    id: rowViewport

    anchors.fill: parent
    clip: true

    Row {
      id: workspacesRow

      height: root.slotH
      spacing: root.spacing
      width: root.fullWidth
      x: root.targetRowX

      Behavior on x {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }

      Repeater {
        model: root.workspaces

        delegate: IconButton {
          required property var modelData
          // modelData may be transiently null; default to {} to avoid TypeErrors
          readonly property var ws: (modelData || ({}))

          bgColor: root.wsColor(ws)
          height: root.slotH
          iconText: "" + ws.idx
          // All listed Niri workspaces exist; do not dim by populated to match Hyprland NormalWorkspaces
          opacity: 1
          width: root.slotW

          Behavior on opacity {
            NumberAnimation {
              duration: Theme.animationDuration
              easing.type: Easing.InOutQuad
            }
          }

          onEntered: {
            root.expanded = true;
            collapseTimer.stop();
            root.hoveredId = ws.id;
          }
          onExited: {
            if (root.hoveredId === ws.id)
              root.hoveredId = 0;
            collapseTimer.restart();
          }
          onLeftClicked: {
            if (!ws.is_focused)
              WorkspaceService.focusWorkspaceByWs(ws);
          }
        }
      }
      Repeater {
        model: root.groupBoundaries.length

        delegate: Rectangle {
          readonly property int boundaryCount: root.groupBoundaries[index]
          required property int index

          anchors.verticalCenter: parent.verticalCenter
          color: Theme.textContrast(Theme.bgColor)
          height: Math.round(root.slotH * 0.6)
          opacity: 0.5
          radius: 1
          width: 2
          x: boundaryCount * (root.slotW + root.spacing) - root.spacing / 2 - width / 2
        }
      }
    }
  }

  // Empty state
  Text {
    anchors.centerIn: parent
    color: Theme.textContrast(Theme.bgColor)
    font.bold: true
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: "No workspaces"
    visible: root.workspaces.length === 0
  }

  // Keep slide alignment in sync with service changes
  Connections {
    function onCurrentWorkspaceChanged() {
    // Behavior on workspacesRow.x will animate to new targetRowX
    // width Behavior handles expand/collapse transitions
    }

    target: WorkspaceService
  }
}
