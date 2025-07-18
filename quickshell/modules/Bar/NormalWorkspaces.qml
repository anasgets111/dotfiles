import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Item {
  id: root
  property bool expanded: false
  property int hoveredIndex: 0

  // slide animation state
  property int currentWorkspace:
    Hyprland.focusedWorkspace
      ? Hyprland.focusedWorkspace.id
      : 1
  property int previousWorkspace: currentWorkspace
  property real slideProgress: 0.0
  property int slideFrom: currentWorkspace
  property int slideTo: currentWorkspace

  Connections {
      target: Hyprland
      function onRawEvent(event) {
          if (event.name === "workspace") {
              var args = event.parse(2)
              var newId = parseInt(args[0])
              if (newId !== currentWorkspace) {
                  previousWorkspace = currentWorkspace
                  currentWorkspace = newId
                  slideFrom       = previousWorkspace
                  slideTo         = currentWorkspace
                  slideAnim.restart()
              }
          }
      }
  }

  NumberAnimation {
    id: slideAnim
    target: root
    property: "slideProgress"
    from: 0.0; to: 1.0
    duration: Theme.animationDuration
  }

  function workspaceColor(ws) {
    if (ws.active)             return Theme.activeColor
    if (ws.id === hoveredIndex) return Theme.onHoverColor
    if (ws.populated)          return Theme.inactiveColor
                                 return Theme.disabledColor
  }

  property var workspaceStatusList: (function() {
    var arr = Hyprland.workspaces.values
    var map = arr.reduce((m, w) => (m[w.id] = w, m), {})
    return Array.from({ length: 10 }, (_, i) => {
      var w = map[i + 1]
      return {
        id:        i + 1,
        active:    !!(w && w.active),
        populated: !!w
      }
    })
  })()

  Timer {
    id: collapseTimer
    interval: Theme.animationDuration + 200
    onTriggered: {
      expanded      = false
      hoveredIndex  = 0
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor

    onEntered: {
      expanded = true
      collapseTimer.stop()
    }
    onExited: collapseTimer.restart()
    onPositionChanged: function(mouse) {
      var sp   = expanded ? Theme.itemWidth + 8 : Theme.itemWidth
      var idx  = Math.floor(mouse.x / sp) + 1
      hoveredIndex = (idx >= 1 && idx <= workspaceStatusList.length)
                     ? idx
                     : 0
    }
    onClicked: {
      if (hoveredIndex > 0)
        Hyprland.dispatch("workspace " + hoveredIndex)
    }
  }

  // collapsed state with slide-in/out
  Rectangle {
    id: collapsedWs
    visible: !expanded
    width: Theme.itemWidth
    height: Theme.itemHeight
    radius: Theme.itemRadius
    color: Theme.bgColor
    clip: true

    property int slideDirection:
      slideTo === slideFrom
        ? -1
        : slideTo > slideFrom
          ? -1
          : 1

    Rectangle {
      width: Theme.itemWidth
      height: Theme.itemHeight
      radius: Theme.itemRadius
      color: workspaceColor({ id: slideFrom,
                              active: true,
                              populated: true })
      x: slideProgress * collapsedWs.slideDirection
         * Theme.itemWidth
      visible: slideProgress < 1
      Text {
        anchors.centerIn: parent
        text: slideFrom
        color: Theme.textContrast(parent.color)
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        font.bold: true
      }
    }

    Rectangle {
      width: Theme.itemWidth
      height: Theme.itemHeight
      radius: Theme.itemRadius
      color: workspaceColor({ id: slideTo,
                              active: true,
                              populated: true })
      x: (slideProgress - 1) * collapsedWs.slideDirection
         * Theme.itemWidth
      Text {
        anchors.centerIn: parent
        text: slideTo
        color: Theme.textContrast(parent.color)
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        font.bold: true
      }
    }
  }

  // expanded grid
  Row {
    id: workspacesRow
    visible: expanded
    spacing: 8

    Repeater {
      model: workspaceStatusList
      delegate: Rectangle {
        property var ws: modelData
        width: (ws.active || expanded)
                 ? Theme.itemWidth
                 : 0
        height: Theme.itemHeight
        radius: Theme.itemRadius
        color: workspaceColor(ws)
        opacity: (ws.active || expanded)
                   ? (ws.populated ? 1 : 0.5)
                   : 0

        Behavior on width {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }
        Behavior on color {
          ColorAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }
        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuart
          }
        }

        Text {
          anchors.centerIn: parent
          text: ws.id
          color: Theme.textContrast(parent.color)
          Behavior on color {
            ColorAnimation {
              duration: Theme.animationDuration
              easing.type: Easing.InOutQuad
            }
          }
          font.pixelSize: Theme.fontSize
          font.family: Theme.fontFamily
          font.bold: true
        }
      }
    }
  }

  Text {
    visible: !workspaceStatusList.some(ws => ws.populated)
    text: "No workspaces"
    color: Theme.textContrast(Theme.bgColor)
    font.pixelSize: Theme.fontSize
    font.family: Theme.fontFamily
    font.bold: true
  }

  width: workspacesRow.width
  height: workspacesRow.height
}
