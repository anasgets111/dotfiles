pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io

// Niri backend for keyboard layouts
Singleton {
    id: niriKeyboardLayoutImpl

    // Toggle to start/stop processes
    property bool enabled: false

    // Public API mirrored by the service
    property var layouts: []
    property string currentLayout: ""

    // Helpers
    function update(namesArr, idxOrActive) {
        var names = (namesArr || []).map(function (n) {
            return String(n || "").trim();
        });
        niriKeyboardLayoutImpl.layouts = names;
        var idx = typeof idxOrActive === "number" ? idxOrActive : -1;
        niriKeyboardLayoutImpl.currentLayout = (idx >= 0 && idx < names.length) ? names[idx] : "";
    }

    // Seed via niri json
    Process {
        id: seedProcNiri
        running: niriKeyboardLayoutImpl.enabled
        command: ["niri", "msg", "--json", "keyboard-layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(text);
                    niriKeyboardLayoutImpl.update(j.names || [], j.current_idx);
                } catch (e) {
                    console.error("[NiriKeyboardLayoutImpl] parse error:", e);
                }
            }
        }
    }

    // Subscribe to event stream and react to layout events
    Process {
        id: eventProcNiri
        running: niriKeyboardLayoutImpl.enabled
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (segment) {
                if (!segment)
                    return;
                try {
                    var evt = JSON.parse(segment);
                    if (evt.KeyboardLayoutsChanged) {
                        var kli = evt.KeyboardLayoutsChanged.keyboard_layouts;
                        niriKeyboardLayoutImpl.update(kli.names || [], kli.current_idx);
                    } else if (evt.KeyboardLayoutSwitched) {
                        var idx = evt.KeyboardLayoutSwitched.idx;
                        if (!niriKeyboardLayoutImpl.layouts.length)
                            return;
                        niriKeyboardLayoutImpl.currentLayout = niriKeyboardLayoutImpl.layouts[idx] || "";
                    }
                } catch (e)
                // ignore parse errors for partial lines
                {}
            }
        }
    }
}
