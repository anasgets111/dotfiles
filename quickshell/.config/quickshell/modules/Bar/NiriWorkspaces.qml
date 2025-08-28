pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
  id: root

  property int currentWorkspace: 1
  property bool expanded: false
  property string focusedOutput: ""
  property var groupBoundaries: []
  property int hoveredId: 0
  property var outputsOrder: []
  property int previousWorkspace: currentWorkspace
  property int slideFrom: currentWorkspace
  property real slideProgress: 0
  property int slideTo: currentWorkspace
  property bool useNiri: true
  property var workspaces: []

  function focusWorkspaceByWs(ws) {
    var out = ws.output || "";
    var idx = ws.idx;
    if (out && out !== root.focusedOutput) {
      var outEsc = out.replace(/'/g, "'\"'\"'");
      var script = "niri msg action focus-monitor '" + outEsc + "' && niri msg action focus-workspace " + idx;
      switchProc.running = false;
      switchProc.command = ["bash", "-lc", script];
      switchProc.running = true;
      return;
    }
    switchProc.running = false;
    switchProc.command = ["niri", "msg", "action", "focus-workspace", String(idx)];
    switchProc.running = true;
  }
  function seedInitial() {
    seedProcWorkspaces.running = true;
  }
  function switchWorkspace(idx) {
    switchProc.running = false;
    switchProc.command = ["niri", "msg", "workspace", String(idx)];
    switchProc.running = true;
  }
  function updateSingleFocus(id) {
    var w = root.workspaces.find(function (ww) {
      return ww.id === id;
    });
    if (!w)
      return;

    root.previousWorkspace = root.currentWorkspace;
    root.currentWorkspace = w.idx;
    root.slideFrom = root.previousWorkspace;
    root.slideTo = root.currentWorkspace;
    root.focusedOutput = w.output || root.focusedOutput;

    root.workspaces.forEach(function (ww) {
      ww.is_focused = (ww.id === id);
      ww.is_active = (ww.id === id);
    });
    // poke bindings
    root.workspaces = root.workspaces;
    slideAnim.restart();
  }
  function updateWorkspaces(arr) {
    arr.forEach(function (w) {
      w.populated = w.active_window_id !== null;
    });

    var f = arr.find(function (w) {
      return w.is_focused;
    });
    if (f)
      root.focusedOutput = f.output || "";

    var groups = {};
    arr.forEach(function (w) {
      var out = w.output || "";
      if (!groups[out])
        groups[out] = [];
      groups[out].push(w);
    });

    var outs = Object.keys(groups).sort(function (a, b) {
      if (a === root.focusedOutput)
        return -1;
      if (b === root.focusedOutput)
        return 1;
      return a.localeCompare(b);
    });
    root.outputsOrder = outs;

    var flat = [];
    var bounds = [];
    var acc = 0;
    outs.forEach(function (out) {
      groups[out].sort(function (a, b) {
        return a.idx - b.idx;
      });
      flat = flat.concat(groups[out]);
      acc += groups[out].length;
      if (acc > 0 && acc < arr.length)
        bounds.push(acc);
    });
    root.workspaces = flat;
    root.groupBoundaries = bounds;

    if (f && f.idx !== root.currentWorkspace) {
      root.previousWorkspace = root.currentWorkspace;
      root.currentWorkspace = f.idx;
      root.slideFrom = root.previousWorkspace;
      root.slideTo = root.currentWorkspace;
      slideAnim.restart();
    }
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

  Component.onCompleted: {
    if (root.useNiri)
      root.seedInitial();
  }

  Process {
    id: seedProcWorkspaces

    command: ["niri", "msg", "--json", "workspaces"]

    stdout: StdioCollector {
      onStreamFinished: {
        var j = JSON.parse(text);
        if (j.Workspaces)
          root.updateWorkspaces(j.Workspaces.workspaces);
      }
    }
  }
  Process {
    id: eventProcNiri

    command: ["niri", "msg", "--json", "event-stream"]
    running: root.useNiri

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: function (seg) {
        if (!seg)
          return;
        var evt = JSON.parse(seg);
        if (evt.WorkspacesChanged)
          root.updateWorkspaces(evt.WorkspacesChanged.workspaces);
        else if (evt.WorkspaceActivated)
          root.updateSingleFocus(evt.WorkspaceActivated.id);
      }
    }
  }
  Process {
    id: switchProc

    command: ["niri", "msg", "workspace", "1"]
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
  MouseArea {
    acceptedButtons: Qt.NoButton
    anchors.fill: parent
    hoverEnabled: true

    onEntered: {
      root.expanded = true;
      collapseTimer.stop();
    }
    onExited: collapseTimer.restart()
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
