import QtQuick
import Quickshell.Io
import Quickshell.Hyprland

Item {
  id: kbService

  // environment flags
  readonly property bool useHypr: DetectEnv.isHyprland
  readonly property bool useNiri: DetectEnv.isNiri

  // public state
  property var    layouts: []
  property string currentLayout: ""
  property bool   available: false

  // “English (US)” → “EN”
  function shortName(full) {
    if (!full) return ""
    var lang = full.trim().split(" ")[0]
    return lang.slice(0, 2).toUpperCase()
  }

  // unify both backends
  // for Hypr: idxOrActive is a string
  // for Niri: idxOrActive is a numeric index
  function update(namesArr, idxOrActive) {
    var names = namesArr.map(function(n) { return n.trim() })
    layouts       = names
    available     = names.length > 1
    if (useHypr) {
      currentLayout = idxOrActive.trim()
    } else {
      currentLayout = names[idxOrActive] || ""
    }
  }

  // kick off one-shot fetch
  function seedInitial() {
    if (useHypr) {
      seedProcHypr.running = true
    } else if (useNiri) {
      seedProcNiri.running = true
    }
  }

  /* ——— Hypr initial fetch ——— */
  Process {
    id: seedProcHypr
    command: ["hyprctl", "-j", "devices"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
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
        } catch (e) {
          console.error("Hypr JSON parse error:", e)
        }
      }
    }
  }

  /* ——— Niri initial fetch ——— */
  Process {
    id: seedProcNiri
    command: ["niri", "msg", "--json", "keyboard-layouts"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var j = JSON.parse(text)
          kbService.update(j.names, j.current_idx)
        } catch (e) {
          console.error("Niri JSON parse error:", e)
        }
      }
    }
  }

  /* ——— Hypr real-time updates ——— */
  Connections {
    target: Hyprland
    enabled: useHypr
    function onRawEvent(event) {
      if (event.name !== "activelayout") return
      var parts = event.data.split(",")
      kbService.update(parts, parts[parts.length - 1])
    }
  }

  /* ——— Niri real-time updates ——— */
  Process {
    id: eventProcNiri
    running: useNiri
    command: ["niri", "msg", "--json", "event-stream"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(segment) {
        if (!segment) return
        try {
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
        } catch (e) {
          console.error("Niri event parse error:", e)
        }
      }
    }
  }

  Component.onCompleted: seedInitial()
}
