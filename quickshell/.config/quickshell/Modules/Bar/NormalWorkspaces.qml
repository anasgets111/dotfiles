pragma ComponentBehavior: Bound
import QtQuick
import qs.Config
import qs.Services
import qs.Services.WM
import qs.Components

Item {
  id: normalWorkspaces

  readonly property var backingWorkspaces: WorkspaceService.workspaces
  readonly property int count: 10
  readonly property int currentWorkspace: Math.max(1, WorkspaceService.currentWorkspace)
  readonly property int focusedIndex: Math.max(0, Math.min(currentWorkspace - 1, count - 1))
  property int hoveredIndex: 0
  // Compatibility: expose expanded for parents listening to onExpandedChanged
  property bool expanded: pill ? pill.expanded : false
  readonly property bool isHyprlandSession: MainService.currentWM === "hyprland"
  readonly property int slotH: Theme.itemHeight
  readonly property int slotW: Theme.itemWidth
  readonly property var slots: Array(10).fill(0).map((_, i) => i + 1)
  readonly property int spacing: 8

  function wsColor(id) {
    if (id === currentWorkspace)
      return Theme.activeColor;
    if (id === hoveredIndex)
      return Theme.onHoverColor;
    const exists = !!backingWorkspaces.find(w => w.id === id);
    return exists ? Theme.inactiveColor : Theme.disabledColor;
  }

  clip: true
  // Size follows the ExpandingPill, like in PowerMenu
  height: pill.height
  visible: isHyprlandSession
  width: pill.width

  // Use the shared ExpandingPill to handle expand/collapse behavior
  ExpandingPill {
    id: pill

    // Keep the same sizing/spacing
    slotW: normalWorkspaces.slotW
    slotH: normalWorkspaces.slotH
    spacing: normalWorkspaces.spacing
    count: normalWorkspaces.count
    // Show the current workspace when collapsed
    collapsedIndex: normalWorkspaces.focusedIndex
    // Match previous collapse delay feel
    collapseDelayMs: Theme.animationDuration + 200
    // Original layout listed items left-to-right with left anchoring
    rightAligned: false

    // Build each workspace button
    delegate: Component {
      IconButton {
        id: btn

        required property int index
        readonly property int idNum: normalWorkspaces.slots[index]

        colorBg: normalWorkspaces.wsColor(idNum)
        icon: "" + idNum
        opacity: !!normalWorkspaces.backingWorkspaces.find(w => w.id === idNum) ? 1 : 0.5

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }

        onEntered: normalWorkspaces.hoveredIndex = idNum
        onExited: if (normalWorkspaces.hoveredIndex === idNum)
          normalWorkspaces.hoveredIndex = 0
        onClicked: if (idNum !== normalWorkspaces.currentWorkspace)
          WorkspaceService.focusWorkspaceByIndex(idNum)
      }
    }
  }
}
