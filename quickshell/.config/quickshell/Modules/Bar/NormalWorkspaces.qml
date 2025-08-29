pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Config
import qs.Services.WM
import qs.Widgets

Item {
  id: normalWorkspaces

  readonly property var backingWorkspaces: WorkspaceService.workspaces
  readonly property int count: 10
  readonly property int currentWorkspace: Math.max(1, WorkspaceService.currentWorkspace)
  property bool expanded: false
  readonly property int focusedIndex: Math.max(0, Math.min(currentWorkspace - 1, count - 1))
  readonly property int fullWidth: count * slotW + Math.max(0, count - 1) * spacing
  property int hoveredIndex: 0
  readonly property bool isHyprlandSession: (Quickshell.env && (Quickshell.env("XDG_SESSION_DESKTOP") === "Hyprland" || Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland" || Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")))
  readonly property int slotH: Theme.itemHeight
  readonly property int slotW: Theme.itemWidth
  readonly property var slots: Array(10).fill(0).map((_, i) => i + 1)
  readonly property int spacing: 8
  readonly property int targetRowX: expanded ? 0 : -(focusedIndex * (slotW + spacing))

  function wsColor(id) {
    if (id === currentWorkspace)
      return Theme.activeColor;
    if (id === hoveredIndex)
      return Theme.onHoverColor;
    const exists = !!backingWorkspaces.find(w => w.id === id);
    return exists ? Theme.inactiveColor : Theme.disabledColor;
  }

  clip: true
  height: slotH
  visible: isHyprlandSession
  width: expanded ? fullWidth : slotW

  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  Timer {
    id: collapseTimer

    interval: Theme.animationDuration + 200

    onTriggered: {
      normalWorkspaces.expanded = false;
      normalWorkspaces.hoveredIndex = 0;
    }
  }
  HoverHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    onHoveredChanged: hovered ? (normalWorkspaces.expanded = true, collapseTimer.stop()) : collapseTimer.restart()
  }
  Item {
    id: rowViewport

    anchors.fill: parent
    clip: true

    Item {
      id: workspacesRow

      height: normalWorkspaces.slotH
      width: normalWorkspaces.fullWidth
      x: normalWorkspaces.targetRowX

      Behavior on x {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }

      Repeater {
        model: normalWorkspaces.slots

        delegate: IconButton {
          readonly property int idNum: modelData
          required property int index   // 0..9
          required property int modelData // 1..10

          bgColor: normalWorkspaces.wsColor(idNum)
          height: normalWorkspaces.slotH
          iconText: "" + idNum

          // dim slots that don't exist in backingWorkspaces
          opacity: !!normalWorkspaces.backingWorkspaces.find(w => w.id === idNum) ? 1 : 0.5
          width: normalWorkspaces.slotW
          x: index * (normalWorkspaces.slotW + normalWorkspaces.spacing)

          Behavior on opacity {
            NumberAnimation {
              duration: Theme.animationDuration
              easing.type: Easing.InOutQuad
            }
          }

          onEntered: {
            normalWorkspaces.expanded = true;
            collapseTimer.stop();
            normalWorkspaces.hoveredIndex = idNum;
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
  }
  Connections {
    function onCurrentWorkspaceChanged() {
    }

    target: WorkspaceService
  }
}
