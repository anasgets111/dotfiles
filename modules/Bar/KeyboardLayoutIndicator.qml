import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell
import Quickshell.Io

Item {
  id: root
  implicitHeight: Theme.itemHeight
  implicitWidth: label.implicitWidth + 12
  visible: layoutService.available

  QtObject {
    id: layoutService
    property var layouts: []
    property string currentLayout: ""
    property bool available: false

    function shortName(full) {
      if (!full) return ""
      var lang = full.trim().split(" ")[0]
      return lang.substring(0,2).toUpperCase()
    }

    function update(layoutsArr, activeFull) {
      layouts = layoutsArr.map(function(x){ return x.trim() })
      available = layouts.length > 1
      var full = activeFull
        ? activeFull.trim()
        : (layouts[layouts.length-1] || "")
      currentLayout = full; // store the full layout name for logic
    }

    function seedInitial() {
      seedProc.running = true
    }


  }

  Process {
    id: seedProc
    command: ["hyprctl", "-j", "devices"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var j = JSON.parse(text)
          var arr = [], active = ""
          j.keyboards.forEach(function(k){
            if (!k.main) return
            k.layout.split(",").forEach(function(l){
              var t = l.trim()
              if (arr.indexOf(t) === -1) arr.push(t)
            })
            active = k.active_keymap
          })
          layoutService.update(arr, active)
        } catch(e) {
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          // Optionally handle errors
        }
      }
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name !== "activelayout") return
      var parts = event.data.split(",")
      layoutService.update(parts, parts[parts.length-1])
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.itemRadius
    color: Theme.inactiveColor
    implicitWidth: label.implicitWidth + 12



    RowLayout {
      anchors.fill: parent

      Text {
        id: label
        text: layoutService.shortName(layoutService.currentLayout)
        font.pixelSize: Theme.fontSize
        color: Theme.textContrast(Theme.inactiveColor)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
      }
    }
  }



  Component.onCompleted: {
    layoutService.seedInitial()
  }
}
