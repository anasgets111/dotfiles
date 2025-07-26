import QtQuick
import Quickshell.Io
import Quickshell.Hyprland

Item {
  id: kbService

  readonly property bool useHypr: DetectEnv.isHyprland
  readonly property bool useNiri: DetectEnv.isNiri
  property var layouts: []
  property string currentLayout: ""
  property bool available: false

  function shortName(full) {
    if (!full) return ""
    var lang = full.trim().split(" ")[0]
    return lang.slice(0, 2).toUpperCase()
  }

  function update(namesArr, idxOrActive) {
    var names = namesArr.map(function(n) { return n.trim() })
    layouts = names
    available = names.length > 1
    if (useHypr) {
      currentLayout = idxOrActive.trim()
    } else {
      currentLayout = names[idxOrActive] || ""
    }
  }

  function seedInitial() {
    if (useHypr) {
      seedProcHypr.running = true
    } else if (useNiri) {
      seedProcNiri.running = true
    }
  }

  Process {
    id: seedProcHypr
    command: ["hyprctl", "-j", "devices"]
    stdout: StdioCollector {
      onStreamFinished: {
        var j = JSON.parse(text)
        var arr = [], active = ""
        j.keyboards.forEach(function(k) {
          if (!k.main) return
          k.layout.split(",").forEach(function(l) {
            var t = l.trim()
            if (arr.indexOf(t) === -1) arr.push(t)
          })
          active = k.active_keymap
        })
        kbService.update(arr, active)
      }
    }
  }

  Process {
    id: seedProcNiri
    command: ["niri", "msg", "--json", "keyboard-layouts"]
    stdout: StdioCollector {
      onStreamFinished: {
        var j = JSON.parse(text)
        kbService.update(j.names, j.current_idx)
      }
    }
  }

  Connections {
    target: Hyprland
    enabled: useHypr
    function onRawEvent(event) {
      if (event.name !== "activelayout") return
      var parts = event.data.split(",")
      kbService.update(parts, parts[parts.length - 1])
    }
  }

  Process {
    id: eventProcNiri
    running: useNiri
    command: ["niri", "msg", "--json", "event-stream"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(segment) {
        if (!segment) return
        var evt = JSON.parse(segment)
        if (evt.KeyboardLayoutsChanged) {
          var kli = evt.KeyboardLayoutsChanged.keyboard_layouts
          kbService.update(kli.names, kli.current_idx)
        } else if (evt.KeyboardLayoutSwitched) {
          var idx = evt.KeyboardLayoutSwitched.idx
          if (!kbService.layouts.length) {
            kbService.seedInitial()
          } else {
            kbService.currentLayout =
              kbService.layouts[idx] || ""
          }
        }
      }
    }
  }

  Component.onCompleted: seedInitial()
}
