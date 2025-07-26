import QtQuick
import Quickshell.Io

Item {
  id: kbService

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

  // update from names[] + idx
  function update(namesArr, idx) {
    var names = namesArr.map(function(n) { return n.trim() })
    layouts       = names
    available     = names.length > 1
    currentLayout = names[idx] || ""
  }

  // trigger initial fetch
  function seedInitial() {
    if (!seedProc.running)
      seedProc.running = true
  }

  // one-off JSON fetch
  Process {
    id: seedProc
    command: ["niri", "msg", "--json", "keyboard-layouts"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var j = JSON.parse(text)
          kbService.update(j.names, j.current_idx)
        } catch (e) {
          console.error("niri JSON parse error:", e)
        }
      }
    }
  }

  // real-time event stream
  Process {
    id: eventProc
    command: ["niri", "msg", "--json", "event-stream"]
    running: true
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(segment) {
        if (!segment) return
          var evt = JSON.parse(segment)
          if (evt.KeyboardLayoutsChanged) {
            var kl = evt.KeyboardLayoutsChanged.keyboard_layouts
            kbService.update(kl.names, kl.current_idx)
          } else if (evt.KeyboardLayoutSwitched) {
            var idx = evt.KeyboardLayoutSwitched.idx
            if (!kbService.layouts.length) {
              kbService.seedInitial()
            } else {
              kbService.currentLayout = kbService.layouts[idx] || ""
            }
          }
      }
    }
  }

  Component.onCompleted: seedInitial()
}
