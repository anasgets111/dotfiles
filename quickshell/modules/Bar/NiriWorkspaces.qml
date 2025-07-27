import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  clip: true
  property bool useNiri: true
  property var workspaces: []

  property bool expanded: false
  property int hoveredIndex: 0
  property int currentWorkspace: 1
  property int previousWorkspace: currentWorkspace
  property real slideProgress: 0.0
  property int slideFrom: currentWorkspace
  property int slideTo: currentWorkspace

  function seedInitial() {
    seedProcWorkspaces.start()
    seedProcWorkspaces.running = true
  }

  function updateWorkspaces(arr) {
    // full replace + resort
    arr.sort(function(a,b){ return a.idx - b.idx })
    workspaces = arr
    var f = arr.find(function(w){return w.is_focused})
    if (f && f.idx !== currentWorkspace) {
      previousWorkspace = currentWorkspace
      currentWorkspace = f.idx
      slideFrom = previousWorkspace
      slideTo = currentWorkspace
      slideAnim.restart()
    }
  }

  function updateSingleFocus(id) {
    previousWorkspace = currentWorkspace
    currentWorkspace = id
    slideFrom = previousWorkspace
    slideTo = currentWorkspace

    // mark only the newly‐focused ws as focused/active
    for (var i = 0; i < workspaces.length; i++) {
      var w = workspaces[i]
      w.is_focused = (w.idx === id)
      w.is_active  = (w.idx === id)
    }
    // re-assign so QML re-draws
    workspaces = workspaces
    slideAnim.restart()
  }

  function workspaceColor(ws) {
    if (ws.is_focused)    return Theme.activeColor
    if (ws.idx === hoveredIndex) return Theme.onHoverColor
    if (ws.is_active)     return Theme.inactiveColor
    return Theme.disabledColor
  }

  ////////////////////////////////////////////////////////////////////////////
  // 1) seed initial list
  Process {
    id: seedProcWorkspaces
    command: ["niri", "msg", "--json", "workspaces"]
    stdout: StdioCollector {
      onStreamFinished: {
        var j = JSON.parse(text)
        if (j.Workspaces)
          root.updateWorkspaces(j.Workspaces.workspaces)
      }
    }
  }

  ////////////////////////////////////////////////////////////////////////////
  // 2) live event‐stream
  Process {
    id: eventProcNiri
    running: useNiri
    command: ["niri", "msg", "--json", "event-stream"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(segment) {
        if (!segment) return
        var evt = JSON.parse(segment)
        if (evt.WorkspacesChanged) {
          root.updateWorkspaces(evt.WorkspacesChanged.workspaces)

        } else if (evt.WorkspaceActivated) {
          // handle focus‐only events
          root.updateSingleFocus(evt.WorkspaceActivated.id)
        }
      }
    }
  }

  ////////////////////////////////////////////////////////////////////////////
  // 3) switch command
  Process {
    id: switchProc
    command: ["niri","msg","workspace","1"]  // placeholder
  }

  Component.onCompleted: {
    if (useNiri) seedInitial()
  }

  ////////////////////////////////////////////////////////////////////////////
  // animation & layout (same as before)…
  width: expanded ? workspacesRow.fullWidth : Theme.itemWidth
  height: Theme.itemHeight
  Behavior on width { NumberAnimation { duration: Theme.animationDuration
                                        easing.type: Easing.InOutQuad } }
  NumberAnimation { id: slideAnim; target: root; property: "slideProgress"
                    from:0.0; to:1.0; duration:Theme.animationDuration }

  Timer { id: collapseTimer; interval: Theme.animationDuration+200
          onTriggered:{ expanded=false; hoveredIndex=0 } }

  MouseArea {
    anchors.fill: parent; hoverEnabled:true; acceptedButtons:Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onEntered:    { expanded=true;  collapseTimer.stop() }
    onExited:     collapseTimer.restart()
    onPositionChanged: function(m) {
      var slot = expanded ? Theme.itemWidth+8 : Theme.itemWidth
      var idx = Math.floor(m.x/slot)+1
      hoveredIndex = (idx>=1 && idx<=workspaces.length) ? idx:0
    }
    onClicked: {
      if (hoveredIndex>0 && hoveredIndex!==currentWorkspace)
        switchWorkspace(hoveredIndex)
    }
  }

  function switchWorkspace(idx) {
    switchProc.stop()
    switchProc.command = ["niri","msg","workspace",String(idx)]
    switchProc.start()
  }

  Item {
    id: workspacesRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    property int spacing: 8
    property int count: workspaces.length
    property int fullWidth:
      count*Theme.itemWidth + Math.max(0,count-1)*spacing
    width: fullWidth; height: Theme.itemHeight

    Repeater {
      model: workspaces
      delegate: Rectangle {
        property var ws: modelData
        width: Theme.itemWidth; height: Theme.itemHeight
        radius: Theme.itemRadius
        color: workspaceColor(ws)
        opacity: ws.is_active ? 1 : 0.5
        property real slotX:
          index*(Theme.itemWidth+workspacesRow.spacing)
        x: expanded ? slotX : 0
        Behavior on x { NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
        }}
        Text {
          anchors.centerIn: parent
          text: ws.idx
          color: Theme.textContrast(parent.color)
          font.pixelSize: Theme.fontSize
          font.family: Theme.fontFamily
          font.bold: true
        }
      }
    }
  }

  Rectangle {
    id: collapsedWs
    visible: !expanded; z:1
    width:Theme.itemWidth; height:Theme.itemHeight
    radius:Theme.itemRadius; color:Theme.bgColor; clip:true
    property int slideDirection:
      slideTo===slideFrom ? -1
      : slideTo>slideFrom   ? -1 : 1

    // from
    Rectangle {
      width:Theme.itemWidth; height:Theme.itemHeight
      radius:Theme.itemRadius
      color: workspaceColor({idx:slideFrom, is_focused:true, is_active:true})
      x: slideProgress * collapsedWs.slideDirection * Theme.itemWidth
      visible: slideProgress<1
      Text {
        anchors.centerIn: parent; text:slideFrom
        color:Theme.textContrast(parent.color)
        font.pixelSize:Theme.fontSize
        font.family:Theme.fontFamily; font.bold:true
      }
    }
    // to
    Rectangle {
      width:Theme.itemWidth; height:Theme.itemHeight
      radius:Theme.itemRadius
      color: workspaceColor({idx:slideTo, is_focused:true, is_active:true})
      x: (slideProgress-1)*collapsedWs.slideDirection*Theme.itemWidth
      Text {
        anchors.centerIn: parent; text:slideTo
        color:Theme.textContrast(parent.color)
        font.pixelSize:Theme.fontSize
        font.family:Theme.fontFamily; font.bold:true
      }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: workspaces.length===0
    text: "No workspaces"
    color: Theme.textContrast(Theme.bgColor)
    font.pixelSize: Theme.fontSize
    font.family: Theme.fontFamily; font.bold: true
  }
}
