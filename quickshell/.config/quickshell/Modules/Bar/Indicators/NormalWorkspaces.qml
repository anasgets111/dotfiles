pragma ComponentBehavior: Bound
import QtQuick
import qs.Config
import qs.Services
import qs.Services.WM
import qs.Components

Item {
  id: root

  readonly property var backingWorkspaces: WorkspaceService.workspaces
  readonly property int count: slotIds.length
  readonly property int currentWorkspace: Math.max(1, WorkspaceService.currentWorkspace)
  property bool expanded: pill?.expanded || false
  readonly property int focusedIndex: Math.max(0, slotIds.indexOf(currentWorkspace))
  property int hoveredId: 0
  readonly property bool isHyprlandSession: MainService.currentWM === "hyprland"
  readonly property int slotH: Theme.itemHeight
  readonly property var slotIds: {
    const ids = (backingWorkspaces ?? []).map(ws => ws.id).filter(id => id > 0);
    const maxId = Math.max(10, currentWorkspace, ...(ids.length ? ids : [0]));
    return Array.from({
      length: maxId
    }, (_, i) => i + 1);
  }
  readonly property int slotW: Theme.itemWidth
  readonly property int spacing: Theme.spacingSm
  readonly property var workspaceMap: {
    const map = {};
    for (const ws of backingWorkspaces ?? [])
      map[ws.id] = ws;
    return map;
  }

  function wsColor(id) {
    if (id === currentWorkspace)
      return Theme.activeColor;
    if (id === hoveredId)
      return Theme.onHoverColor;
    const ws = workspaceMap[id];
    if (ws)
      return ws.populated ? Theme.inactiveColor : Theme.disabledColor;
    return Theme.disabledColor;
  }

  clip: true
  height: pill.height
  visible: isHyprlandSession && count > 0
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

        readonly property int idNum: root.slotIds[index]
        required property int index

        colorBg: root.wsColor(idNum)
        icon: String(idNum)
        opacity: (root.workspaceMap[idNum]?.populated ?? false) ? 1 : 0.5

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }

        onClicked: if (idNum !== root.currentWorkspace)
          WorkspaceService.focusWorkspaceByIndex(idNum)
        onEntered: root.hoveredId = idNum
        onExited: if (root.hoveredId === idNum)
          root.hoveredId = 0
      }
    }
  }
}
