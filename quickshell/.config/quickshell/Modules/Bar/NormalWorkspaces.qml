pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
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

  // Where we want the viewport to scroll to when collapsed:
  readonly property int targetContentX: expanded ? 0 : Math.max(0, Math.min(Math.round(focusedIndex * (slotW + spacing)), Math.max(0, fullWidth - width)))

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

  // react to state changes by adjusting the scroll target
  onExpandedChanged: viewport.contentX = targetContentX
  onFocusedIndexChanged: if (!expanded)
    viewport.contentX = targetContentX
  onFullWidthChanged: viewport.contentX = targetContentX

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

    onHoveredChanged: {
      if (hovered) {
        normalWorkspaces.expanded = true;
        collapseTimer.stop();
      } else
        collapseTimer.restart();
    }
  }

  // Flickable serves as horizontal viewport for the RowLayout content
  Flickable {
    id: viewport

    anchors.fill: parent
    clip: true
    contentHeight: rowWrapper.implicitHeight
    contentWidth: rowWrapper.implicitWidth
    interactive: false  // UX is hover-driven, not finger scroll

    // animate contentX to mimic the old Behavior on x
    Behavior on contentX {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.InOutQuad
      }
    }

    Component.onCompleted: contentX = normalWorkspaces.targetContentX

    // Keep content aligned with desired target whenever these change
    onWidthChanged: contentX = normalWorkspaces.targetContentX

    Item {
      id: rowWrapper

      // implicit size is driven by RowLayout content
      implicitHeight: normalWorkspaces.slotH
      implicitWidth: normalWorkspaces.fullWidth

      RowLayout {
        id: rowLayout

        anchors.fill: parent
        spacing: normalWorkspaces.spacing

        Repeater {
          model: normalWorkspaces.slots

          delegate: IconButton {
            readonly property int idNum: modelData
            required property int index
            required property int modelData

            Layout.preferredHeight: normalWorkspaces.slotH

            // place via layout, not x
            Layout.preferredWidth: normalWorkspaces.slotW
            bgColor: normalWorkspaces.wsColor(idNum)
            height: normalWorkspaces.slotH
            iconText: "" + idNum

            // dim if not in backingWorkspaces
            opacity: !!normalWorkspaces.backingWorkspaces.find(w => w.id === idNum) ? 1 : 0.5
            width: normalWorkspaces.slotW

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
  }
  Connections {
    function onCurrentWorkspaceChanged() {
      // keep centering on the new workspace when collapsed
      if (!normalWorkspaces.expanded)
        viewport.contentX = normalWorkspaces.targetContentX;
    }

    target: WorkspaceService
  }
}
