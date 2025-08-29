pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Services.WM

Item {
  id: root

  property int currentWorkspace: WorkspaceService.currentWorkspace > 0 ? WorkspaceService.currentWorkspace : 1
  property bool expanded: false
  property string focusedOutput: WorkspaceService.focusedOutput || ""
  property var groupBoundaries: WorkspaceService.groupBoundaries
  property int hoveredId: 0
  property var outputsOrder: WorkspaceService.outputsOrder
  property int previousWorkspace: currentWorkspace
  property int slideFrom: currentWorkspace
  property real slideProgress: 0
  property int slideTo: currentWorkspace
  property var workspaces: WorkspaceService.workspaces

  // All control/state comes from service for both Niri and Hyprland
  function focusWorkspaceByWs(ws) {
    WorkspaceService.focusWorkspaceByWs(ws);
  }
  function workspaceColor(ws) {
    if (ws.is_focused)
      return Theme.activeColor;
    if (ws.id === root.hoveredId)
      return Theme.onHoverColor;
    if (ws.populated)
      return Theme.inactiveColor;
    return Theme.disabledColor;
  }

  clip: true
  height: Theme.itemHeight
  width: root.expanded ? workspacesRow.fullWidth : Theme.itemWidth

  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  // Drive slide animation when service changes current workspace
  Connections {
    function onCurrentWorkspaceChanged() {
      root.slideFrom = root.currentWorkspace;
      root.currentWorkspace = WorkspaceService.currentWorkspace > 0 ? WorkspaceService.currentWorkspace : 1;
      root.slideTo = root.currentWorkspace;
      slideAnim.restart();
    }

    target: WorkspaceService
  }
  // No direct Niri processes here; handled by WorkspaceService backend
  NumberAnimation {
    id: slideAnim

    duration: Theme.animationDuration
    from: 0
    property: "slideProgress"
    target: root
    to: 1
  }
  Timer {
    id: collapseTimer

    interval: Theme.animationDuration + 200

    onTriggered: {
      root.expanded = false;
      root.hoveredId = 0;
    }
  }
  HoverHandler {
    id: rootHover

    onHoveredChanged: {
      if (hovered) {
        root.expanded = true;
        collapseTimer.stop();
      } else {
        collapseTimer.restart();
      }
    }
  }
  Item {
    id: workspacesRow

    property int count: root.workspaces.length
    property int fullWidth: workspacesRow.count * Theme.itemWidth + Math.max(0, workspacesRow.count - 1) * workspacesRow.spacing
    property int spacing: 8

    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    height: Theme.itemHeight
    visible: root.expanded
    width: workspacesRow.fullWidth

    Repeater {
      model: root.workspaces

      delegate: Rectangle {
        id: wsRect

        required property int index
        required property var modelData
        property real slotX: wsRect.index * (Theme.itemWidth + workspacesRow.spacing)
        property var ws: wsRect.modelData

        color: root.workspaceColor(wsRect.ws)
        height: Theme.itemHeight
        opacity: wsRect.ws.populated ? 1 : 0.5
        radius: Theme.itemRadius
        width: Theme.itemWidth
        x: wsRect.slotX

        Behavior on x {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }

        MouseArea {
          acceptedButtons: Qt.LeftButton
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          onClicked: {
            if (!wsRect.ws.is_focused)
              root.focusWorkspaceByWs(wsRect.ws);
          }
          onEntered: root.hoveredId = wsRect.ws.id
          onExited: root.hoveredId = 0
        }
        Text {
          anchors.centerIn: parent
          color: Theme.textContrast(wsRect.color)
          font.bold: true
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          text: wsRect.ws.idx
        }
      }
    }
    Repeater {
      model: root.groupBoundaries.length

      delegate: Rectangle {
        id: boundary

        property int boundaryCount: root.groupBoundaries[boundary.index]
        required property int index

        anchors.verticalCenter: workspacesRow.verticalCenter
        color: Theme.textContrast(Theme.bgColor)
        height: Math.round(workspacesRow.height * 0.6)
        opacity: 0.5
        radius: 1
        width: 2
        x: boundary.boundaryCount * (Theme.itemWidth + workspacesRow.spacing) - workspacesRow.spacing / 2 - boundary.width / 2
      }
    }
  }
  Rectangle {
    id: collapsedWs

    property int slideDirection: root.slideTo === root.slideFrom ? -1 : (root.slideTo > root.slideFrom ? -1 : 1)

    clip: true
    color: Theme.bgColor
    height: Theme.itemHeight
    radius: Theme.itemRadius
    visible: !root.expanded
    width: Theme.itemWidth
    z: 1

    Rectangle {
      id: fromRect

      color: root.workspaceColor({
        "idx": root.slideFrom,
        "is_focused": true,
        "populated": true
      })
      height: Theme.itemHeight
      radius: Theme.itemRadius
      visible: root.slideProgress < 1
      width: Theme.itemWidth
      x: root.slideProgress * collapsedWs.slideDirection * Theme.itemWidth

      Text {
        anchors.centerIn: parent
        color: Theme.textContrast(fromRect.color)
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: root.slideFrom
      }
    }
    Rectangle {
      id: toRect

      color: root.workspaceColor({
        "idx": root.slideTo,
        "is_focused": true,
        "populated": true
      })
      height: Theme.itemHeight
      radius: Theme.itemRadius
      width: Theme.itemWidth
      x: (root.slideProgress - 1) * collapsedWs.slideDirection * Theme.itemWidth

      Text {
        anchors.centerIn: parent
        color: Theme.textContrast(toRect.color)
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: root.slideTo
      }
    }
  }
  Text {
    id: emptyLabel

    anchors.centerIn: parent
    color: Theme.textContrast(Theme.bgColor)
    font.bold: true
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: "No workspaces"
    visible: root.workspaces.length === 0
  }
}
