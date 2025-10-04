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
  readonly property int focusedIndex: Math.max(0, Math.min(currentWorkspace - 1, count - 1))
  property int hoveredIndex: 0
  property bool expanded: pill?.expanded || false
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
  height: pill.height
  visible: isHyprlandSession
  width: pill.width

  ExpandingPill {
    id: pill
    slotW: root.slotW
    slotH: root.slotH
    spacing: root.spacing
    count: root.count
    collapsedIndex: root.focusedIndex
    collapseDelayMs: Theme.animationDuration + 200
    rightAligned: false

    delegate: Component {
      IconButton {
        id: btn
        required property int index
        readonly property int idNum: root.slots[index]

        colorBg: root.wsColor(idNum)
        icon: String(idNum)
        opacity: !!root.backingWorkspaces.find(w => w.id === idNum) ? 1 : 0.5

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }

        onEntered: root.hoveredIndex = idNum
        onExited: if (root.hoveredIndex === idNum)
          root.hoveredIndex = 0
        onClicked: if (idNum !== root.currentWorkspace)
          WorkspaceService.focusWorkspaceByIndex(idNum)
      }
    }
  }
}
