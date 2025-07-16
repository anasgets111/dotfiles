import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell
import Quickshell.Io

Item {
  id: root
  implicitHeight: Theme.itemHeight
  implicitWidth: label.implicitWidth
  visible: layoutService.available

  QtObject {
    id: layoutService

    property string currentLayout: ""
    property var    layouts:        []
    property bool   available:      false

    function parseLayout(fullName) {
      if (!fullName) return
      var shortName = fullName.substring(0,2).toUpperCase()
      if (currentLayout !== shortName)
        currentLayout = shortName

    }

    function handleRawEvent(event) {
      if (event.name !== "activelayout") return
      var info      = event.data.split(",")
      layouts       = info
      available     = info.length > 1

      parseLayout(info[info.length - 1])

    }

    function seedInitial() {
      // Start the process to get layouts
      hyprctlProc.running = true
    }
  }

  // Process to run hyprctl -j devices
  Process {
    id: hyprctlProc
    command: ["hyprctl", "-j", "devices"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var j = JSON.parse(this.text)
          var arr = []
          var activeLayout = ""
          j.keyboards.forEach(function(kbd) {
            if (kbd.main) {
              // Collect all layouts
              kbd.layout.split(",").forEach(function(l) {
                var t = l.trim()
                if (arr.indexOf(t) === -1) arr.push(t)
              })
              // Use the active_keymap for the main keyboard
              activeLayout = kbd.active_keymap
            }
          })
          layoutService.layouts   = arr
          layoutService.available = arr.length > 1
          if (activeLayout) {
            // Map the active_keymap to a short code
            var shortName = ""
            if (activeLayout.indexOf("English") !== -1) shortName = "EN"
            else if (activeLayout.indexOf("Arabic") !== -1) shortName = "AR"
            else if (activeLayout.indexOf("Egypt") !== -1) shortName = "EG"
            else shortName = activeLayout.substring(0,2).toUpperCase()
            layoutService.currentLayout = shortName

          } else if (arr.length) {
            layoutService.parseLayout(arr[arr.length - 1])
          }
        } catch (e) {

        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        // (logging removed)
      }
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      layoutService.handleRawEvent(event)
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.itemRadius
    color: Theme.inactiveColor
    implicitWidth: label.implicitWidth + 20
  }

  RowLayout {
    anchors.fill: parent

    MouseArea {
      // Remove anchors.fill: parent, use Layout.fillWidth/Height for layout compliance
      Layout.fillWidth: true
      Layout.fillHeight: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        var idx = layoutService.layouts.indexOf(layoutService.currentLayout)
        var nextIdx = (idx + 1) % layoutService.layouts.length
        var next = layoutService.layouts[nextIdx]
        setxkbmapProc.command = ["setxkbmap", next]
        setxkbmapProc.running = true
        // Do NOT set currentLayout here! Wait for Hyprland event to update it.
      }
    }

    Text {
      id: label
      text: layoutService.currentLayout
      font.pixelSize: Theme.fontSize
      color: Theme.textContrast(Theme.inactiveColor)
    }
  }

  // Process to run setxkbmap
  Process {
    id: setxkbmapProc
    command: []
    running: false
  }

  Component.onCompleted: {
    // seed the very first state before any 'activelayout' fires
    layoutService.seedInitial()
  }
}
