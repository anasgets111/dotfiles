pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Services.WM
import qs.Components

Item {
  id: root

  readonly property var displayWorkspaces: WorkspaceService.displayWorkspaces ?? []
  readonly property bool expanded: pill?.expanded ?? false
  readonly property int focusedSlotIndex: {
    const idx = displayWorkspaces.findIndex(slot => (slot?.workspace?.focused ?? slot?.focused) ?? false);
    return Math.max(0, idx);
  }
  property string hoveredSlotKey: ""
  readonly property int slotH: Theme.itemHeight
  readonly property int slotW: Theme.itemWidth
  readonly property int spacing: Theme.spacingSm

  function slotKey(slot: var): string {
    const workspaceId = slot?.workspace?.id;
    if (workspaceId !== undefined && workspaceId !== null)
      return `ws:${workspaceId}`;
    return `slot:${slot?.idx ?? -1}`;
  }

  function computeWorkspaceColor(slot: var): color {
    if (!slot)
      return Theme.disabledColor;
    const workspace = slot.workspace ?? null;
    if ((workspace?.focused ?? slot.focused) ?? false)
      return Theme.activeColor;
    if (slotKey(slot) === hoveredSlotKey)
      return Theme.onHoverColor;
    return (workspace?.populated ?? false) ? Theme.inactiveColor : Theme.disabledColor;
  }

  clip: true
  height: pill.height
  visible: displayWorkspaces.length > 0
  width: pill.width

  ExpandingPill {
    id: pill

    collapseDelayMs: Theme.animationDuration + 200
    collapsedIndex: root.focusedSlotIndex
    count: root.displayWorkspaces.length
    rightAligned: false
    slotH: root.slotH
    slotW: root.slotW
    spacing: root.spacing

    delegate: IconButton {
      required property int index
      readonly property var slot: root.displayWorkspaces[index] ?? null
      readonly property var workspace: slot?.workspace ?? null

      colorBg: root.computeWorkspaceColor(slot)
      icon: String(workspace?.idx ?? slot?.idx ?? index + 1)
      opacity: workspace?.populated ? 1.0 : 0.5

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }

      onClicked: {
        if (!slot || ((workspace?.focused ?? slot.focused) ?? false))
          return;

        if (workspace) {
          WorkspaceService.focusWorkspace(workspace);
        } else if ((slot.idx ?? 0) > 0) {
          WorkspaceService.focusWorkspaceByIndex(slot.idx);
        }
      }
      onEntered: root.hoveredSlotKey = root.slotKey(slot)
      onExited: {
        if (root.hoveredSlotKey === root.slotKey(slot))
          root.hoveredSlotKey = "";
      }
    }
  }
}
