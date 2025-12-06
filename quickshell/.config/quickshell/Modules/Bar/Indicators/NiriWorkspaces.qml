pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Services.WM
import qs.Components

Item {
  id: root

  readonly property int currentWsId: WorkspaceService.currentWorkspaceId
  readonly property bool expanded: pill.expanded
  readonly property int focusedIndex: {
    const idx = workspaces.findIndex(ws => ws.id === currentWsId);
    return idx >= 0 ? idx : 0;
  }
  readonly property var groupBoundaries: WorkspaceService.groupBoundaries
  property int hoveredId: 0
  readonly property int slotH: Theme.itemHeight
  readonly property int slotW: Theme.itemWidth
  readonly property int spacing: Theme.spacingSm
  readonly property var workspaces: WorkspaceService.workspaces

  function wsColor(ws) {
    if (!ws)
      return Theme.disabledColor;
    if (ws.focused || ws.id === currentWsId)
      return Theme.activeColor;
    if (ws.id === hoveredId)
      return Theme.onHoverColor;
    return ws.populated ? Theme.inactiveColor : Theme.disabledColor;
  }

  clip: true
  height: pill.height
  visible: workspaces.length > 0
  width: pill.width

  ExpandingPill {
    id: pill

    collapseDelayMs: Theme.animationDuration + 200
    collapsedIndex: root.focusedIndex
    count: root.workspaces.length
    rightAligned: false
    slotH: root.slotH
    slotW: root.slotW
    spacing: root.spacing

    delegate: Component {
      IconButton {
        required property int index
        readonly property var ws: root.workspaces[index] ?? {}

        colorBg: root.wsColor(ws)
        icon: String(ws.idx ?? index + 1)

        onClicked: if (!ws.focused)
          WorkspaceService.focusWorkspaceByWs(ws)
        onEntered: {
          pill.expanded = true;
          root.hoveredId = ws.id;
        }
        onExited: if (root.hoveredId === ws.id)
          root.hoveredId = 0
      }
    }
  }

  // Group boundary dividers
  Repeater {
    model: root.groupBoundaries.length

    delegate: Rectangle {
      readonly property int boundaryIdx: root.groupBoundaries[index]
      required property int index

      anchors.verticalCenter: parent.verticalCenter
      color: Theme.textContrast(Theme.bgColor)
      height: Math.round(root.slotH * 0.6)
      opacity: pill.expanded ? 0.5 : 0
      radius: 1
      visible: pill.expanded
      width: 2
      x: boundaryIdx * (root.slotW + root.spacing) - root.spacing / 2 - 1

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }
    }
  }
}
