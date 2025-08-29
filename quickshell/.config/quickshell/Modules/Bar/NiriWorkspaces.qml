pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Services.WM
import qs.Widgets

Item {
  id: root

  property int currentWorkspace: WorkspaceService.currentWorkspace > 0 ? WorkspaceService.currentWorkspace : 1

  // UI state
  property bool expanded: false
  property var groupBoundaries: WorkspaceService.groupBoundaries
  property int hoveredId: 0
  property int slideFrom: currentWorkspace
  property real slideProgress: 0
  property int slideTo: currentWorkspace

  // Service-driven state
  property var workspaces: WorkspaceService.workspaces

  function wsColor(ws) {
    if (ws.is_focused)
      return Theme.activeColor;
    if (ws.id === hoveredId)
      return Theme.onHoverColor;
    return ws.populated ? Theme.inactiveColor : Theme.disabledColor;
  }

  clip: true
  height: Theme.itemHeight
  width: expanded ? workspacesRow.fullWidth : Theme.itemWidth

  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  // Drive slide animation on current workspace change
  Connections {
    function onCurrentWorkspaceChanged() {
      root.slideFrom = root.currentWorkspace;
      root.currentWorkspace = WorkspaceService.currentWorkspace > 0 ? WorkspaceService.currentWorkspace : 1;
      root.slideTo = root.currentWorkspace;
      slideAnim.restart();
    }

    target: WorkspaceService
  }
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

    onHoveredChanged: hovered ? (root.expanded = true, collapseTimer.stop()) : collapseTimer.restart()
  }
  Item {
    id: workspacesRow

    property int count: root.workspaces.length
    readonly property int fullWidth: count * Theme.itemWidth + Math.max(0, count - 1) * spacing
    property int spacing: 8

    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    height: Theme.itemHeight
    visible: root.expanded
    width: fullWidth

    Repeater {
      model: root.workspaces

      delegate: IconButton {
        id: wsBtn

        required property int index
        required property var modelData
        readonly property real slotX: index * (Theme.itemWidth + workspacesRow.spacing)
        readonly property var ws: modelData

        bgColor: root.wsColor(ws)
        height: Theme.itemHeight
        iconText: "" + ws.idx
        opacity: ws.populated ? 1 : 0.5
        width: Theme.itemWidth
        x: slotX

        // Animate reflow when spacing or order changes
        Behavior on x {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }

        onEntered: {
          root.expanded = true;
          collapseTimer.stop();
          root.hoveredId = ws.id;
        }
        onExited: {
          if (root.hoveredId === ws.id)
            root.hoveredId = 0;
          collapseTimer.restart();
        }
        onLeftClicked: {
          if (!ws.is_focused)
            WorkspaceService.focusWorkspaceByWs(ws);
        }
      }
    }

    // Group boundaries
    Repeater {
      model: root.groupBoundaries.length

      delegate: Rectangle {
        property int boundaryCount: root.groupBoundaries[index]
        required property int index

        anchors.verticalCenter: workspacesRow.verticalCenter
        color: Theme.textContrast(Theme.bgColor)
        height: Math.round(workspacesRow.height * 0.6)
        opacity: 0.5
        radius: 1
        width: 2
        x: boundaryCount * (Theme.itemWidth + workspacesRow.spacing) - workspacesRow.spacing / 2 - width / 2
      }
    }
  }

  // Collapsed single slot slide animation
  Rectangle {
    id: collapsedWs

    readonly property int slideDirection: root.slideTo === root.slideFrom ? -1 : (root.slideTo > root.slideFrom ? -1 : 1)

    clip: true
    color: Theme.bgColor
    height: Theme.itemHeight
    radius: Theme.itemRadius
    visible: !root.expanded
    width: Theme.itemWidth

    Rectangle {
      id: fromRect

      color: root.wsColor({
        id: root.slideFrom,
        idx: root.slideFrom,
        is_focused: true,
        populated: true
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

      color: root.wsColor({
        id: root.slideTo,
        idx: root.slideTo,
        is_focused: true,
        populated: true
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
