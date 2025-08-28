pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
  id: normalWorkspaces

  // Workspace animation state
  property int currentWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

  // State
  property bool expanded: false
  property int hoveredIndex: 0
  readonly property bool isHyprlandSession: (Quickshell.env && (Quickshell.env("XDG_SESSION_DESKTOP") === "Hyprland" || Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland" || Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")))
  property int slideFrom: normalWorkspaces.currentWorkspace
  property real slideProgress: 0
  property int slideTo: normalWorkspaces.currentWorkspace

  // Build a fixed-length [1..10] status list from Hyprland.workspaces
  property var workspaceStatusList: (function () {
      const arr = Hyprland.workspaces.values;
      const map = arr.reduce(function (m, w) {
        m[w.id] = w;
        return m;
      }, {});
      const len = 10;
      const out = new Array(len);
      for (var i = 0; i < len; i++) {
        const id = i + 1;
        const w = map[id];
        out[i] = {
          id: id,
          focused: !!(w && w.focused),
          populated: !!w
        };
      }
      return out;
    })()

  function workspaceColor(ws) {
    if (ws.focused)
      return Theme.activeColor;
    if (ws.id === normalWorkspaces.hoveredIndex)
      return Theme.onHoverColor;
    if (ws.populated)
      return Theme.inactiveColor;
    return Theme.disabledColor;
  }

  clip: true
  height: Theme.itemHeight
  visible: normalWorkspaces.isHyprlandSession
  width: normalWorkspaces.expanded ? workspacesRow.fullWidth : Theme.itemWidth

  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  Connections {
    function onRawEvent(evt) {
      if (evt.name !== "workspace")
        return;
      const args = evt.parse(2);
      const newId = parseInt(args[0]);
      if (newId === normalWorkspaces.currentWorkspace)
        return;

      normalWorkspaces.slideFrom = normalWorkspaces.currentWorkspace;
      normalWorkspaces.currentWorkspace = newId;
      normalWorkspaces.slideTo = normalWorkspaces.currentWorkspace;
      slideAnim.restart();
    }

    target: Hyprland
  }

  NumberAnimation {
    id: slideAnim

    duration: Theme.animationDuration
    from: 0
    property: "slideProgress"
    target: normalWorkspaces
    to: 1
  }

  Timer {
    id: collapseTimer

    interval: Theme.animationDuration + 200

    onTriggered: {
      normalWorkspaces.expanded = false;
      normalWorkspaces.hoveredIndex = 0;
    }
  }

  MouseArea {
    acceptedButtons: Qt.LeftButton
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: {
      if (normalWorkspaces.hoveredIndex <= 0)
        return;
      const ws = normalWorkspaces.workspaceStatusList[normalWorkspaces.hoveredIndex - 1];
      if (!ws.focused)
        Hyprland.dispatch("workspace " + normalWorkspaces.hoveredIndex);
    }
    onEntered: {
      normalWorkspaces.expanded = true;
      collapseTimer.stop();
    }
    onExited: collapseTimer.restart()
    onPositionChanged: function (mouse) {
      const slotWidth = normalWorkspaces.expanded ? (Theme.itemWidth + workspacesRow.spacing) : Theme.itemWidth;
      const idx = Math.floor(mouse.x / slotWidth) + 1;
      const len = normalWorkspaces.workspaceStatusList.length;
      normalWorkspaces.hoveredIndex = (idx >= 1 && idx <= len) ? idx : 0;
    }
  }

  Item {
    id: workspacesRow

    readonly property int count: normalWorkspaces.workspaceStatusList.length
    readonly property int fullWidth: workspacesRow.count * Theme.itemWidth + Math.max(0, workspacesRow.count - 1) * workspacesRow.spacing
    property int spacing: 8

    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    height: Theme.itemHeight
    width: workspacesRow.fullWidth

    Repeater {
      model: normalWorkspaces.workspaceStatusList

      delegate: Rectangle {
        id: wsRect

        required property int index
        required property var modelData
        readonly property real slotX: wsRect.index * (Theme.itemWidth + workspacesRow.spacing)
        property var ws: wsRect.modelData

        color: normalWorkspaces.workspaceColor(wsRect.ws)
        height: Theme.itemHeight
        opacity: wsRect.ws.populated ? 1 : 0.5
        radius: Theme.itemRadius
        width: Theme.itemWidth
        x: normalWorkspaces.expanded ? wsRect.slotX : 0

        Behavior on x {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }

        Text {
          anchors.centerIn: parent
          color: Theme.textContrast(wsRect.color)
          font.bold: true
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          text: wsRect.ws.id
        }
      }
    }
  }

  Rectangle {
    id: collapsedWs

    readonly property int slideDirection: normalWorkspaces.slideTo === normalWorkspaces.slideFrom ? -1 : (normalWorkspaces.slideTo > normalWorkspaces.slideFrom ? -1 : 1)

    clip: true
    color: Theme.bgColor
    height: Theme.itemHeight
    radius: Theme.itemRadius
    visible: !normalWorkspaces.expanded
    width: Theme.itemWidth
    z: 1

    // From
    Rectangle {
      color: normalWorkspaces.workspaceColor({
        "id": normalWorkspaces.slideFrom,
        "focused": true,
        "populated": true
      })
      height: Theme.itemHeight
      radius: Theme.itemRadius
      visible: normalWorkspaces.slideProgress < 1
      width: Theme.itemWidth
      x: normalWorkspaces.slideProgress * collapsedWs.slideDirection * Theme.itemWidth

      Text {
        anchors.centerIn: parent
        color: Theme.textContrast(parent.color)
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: normalWorkspaces.slideFrom
      }
    }

    // To
    Rectangle {
      color: normalWorkspaces.workspaceColor({
        "id": normalWorkspaces.slideTo,
        "focused": true,
        "populated": true
      })
      height: Theme.itemHeight
      radius: Theme.itemRadius
      width: Theme.itemWidth
      x: (normalWorkspaces.slideProgress - 1) * collapsedWs.slideDirection * Theme.itemWidth

      Text {
        anchors.centerIn: parent
        color: Theme.textContrast(parent.color)
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: normalWorkspaces.slideTo
      }
    }
  }

  Text {
    anchors.centerIn: parent
    color: Theme.textContrast(Theme.bgColor)
    font.bold: true
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: "No workspaces"
    visible: !normalWorkspaces.workspaceStatusList.some(function (ws) {
      return ws.populated;
    })
  }
}
