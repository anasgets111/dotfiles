pragma ComponentBehavior: Bound
import QtQuick
import qs.Config
import qs.Services
import qs.Services.WM
import qs.Components

Item {
  id: root

  readonly property var backingWorkspaces: WorkspaceService.workspaces
  readonly property int count: 10
  readonly property int currentWorkspace: Math.max(1, WorkspaceService.currentWorkspace)
  property bool expanded: pill?.expanded || false
  readonly property int focusedIndex: Math.max(0, Math.min(currentWorkspace - 1, count - 1))
  property int hoveredIndex: 0
  readonly property bool isHyprlandSession: MainService.currentWM === "hyprland"
  readonly property int slotH: Theme.itemHeight
  readonly property int slotW: Theme.itemWidth
  readonly property var slots: Array(10).fill(0).map((_, i) => i + 1)
  readonly property int spacing: Theme.spacingSm

  function wsColor(id) {
    if (id === currentWorkspace)
      return Theme.activeColor;
    if (id === hoveredIndex)
      return Theme.onHoverColor;
    const exists = !!backingWorkspaces.find(w => w.id === id);
    return exists ? Theme.inactiveColor : Theme.disabledColor;
  }

  clip: true
  height: pill.height
  visible: isHyprlandSession
  width: pill.width

  ExpandingPill {
    id: pill

    collapseDelayMs: Theme.animationDuration + 200
    collapsedIndex: root.focusedIndex
    count: root.count
    rightAligned: false
    slotH: root.slotH
    slotW: root.slotW
    spacing: root.spacing

    delegate: Component {
      IconButton {
        id: btn

        readonly property int idNum: root.slots[index]
        required property int index

        colorBg: root.wsColor(idNum)
        icon: String(idNum)
        opacity: !!root.backingWorkspaces.find(w => w.id === idNum) ? 1 : 0.5

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }

        onClicked: if (idNum !== root.currentWorkspace)
          WorkspaceService.focusWorkspaceByIndex(idNum)
        onEntered: root.hoveredIndex = idNum
        onExited: if (root.hoveredIndex === idNum)
          root.hoveredIndex = 0
      }
    }
  }
}
