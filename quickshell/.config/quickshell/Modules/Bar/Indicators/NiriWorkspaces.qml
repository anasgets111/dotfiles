pragma ComponentBehavior: Bound
import QtQuick
import qs.Config
import qs.Services.WM
import qs.Components

Item {
  id: root

  readonly property int currentWorkspaceId: WorkspaceService.currentWorkspace
  readonly property bool expanded: expandingPill.expanded
  readonly property int focusedSlotIndex: {
    const idx = workspaces.findIndex(ws => ws.focused);
    return Math.max(0, idx);
  }
  property int hoveredWorkspaceId: 0
  readonly property int slotH: Theme.itemHeight
  readonly property int slotW: Theme.itemWidth
  readonly property int spacing: Theme.spacingSm
  readonly property var workspaces: WorkspaceService.workspaces ?? []

  function computeWorkspaceColor(ws: var): color {
    if (!ws)
      return Theme.disabledColor;
    if (ws.focused)
      return Theme.activeColor;
    if (ws.id === hoveredWorkspaceId)
      return Theme.onHoverColor;
    return ws.populated ? Theme.inactiveColor : Theme.disabledColor;
  }

  clip: true
  height: expandingPill.height
  visible: workspaces.length > 0
  width: expandingPill.width

  ExpandingPill {
    id: expandingPill

    collapseDelayMs: Theme.animationDuration + 200
    collapsedIndex: root.focusedSlotIndex
    count: root.workspaces.length
    rightAligned: false
    slotH: root.slotH
    slotW: root.slotW
    spacing: root.spacing

    delegate: IconButton {
      required property int index
      readonly property var ws: root.workspaces[index] ?? {}

      colorBg: root.computeWorkspaceColor(ws)
      icon: String(ws.idx ?? index + 1)
      opacity: ws.populated ? 1.0 : 0.5

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }

      onClicked: {
        if (!ws.focused) {
          WorkspaceService.focusWorkspaceByWs(ws);
        }
      }
      onEntered: root.hoveredWorkspaceId = ws.id
      onExited: {
        if (root.hoveredWorkspaceId === ws.id) {
          root.hoveredWorkspaceId = 0;
        }
      }
    }
  }
}
