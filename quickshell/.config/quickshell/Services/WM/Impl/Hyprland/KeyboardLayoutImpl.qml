pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland

// Hyprland backend for keyboard layouts
Singleton {
    id: hyprKeyboardLayoutImpl

    // Toggle to start/stop processes and connections
    property bool enabled: false

    // Public API mirrored by the service
    property var layouts: []
    property string currentLayout: ""

    // Helpers
    function update(namesArr, idxOrActive) {
        var names = (namesArr || []).map(function (n) {
            return String(n || "").trim();
        });
        hyprKeyboardLayoutImpl.layouts = names;
        // On Hyprland current is the active keymap name (string)
        hyprKeyboardLayoutImpl.currentLayout = String(idxOrActive || "").trim();
    }

    // Seed from hyprctl when enabled
    Process {
        id: seedProcHypr
        running: hyprKeyboardLayoutImpl.enabled
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!hyprKeyboardLayoutImpl.enabled)
                    return;
                try {
                    var j = JSON.parse(text);
                    var arr = [], active = "";
                    j.keyboards.forEach(function (k) {
                        if (!k.main)
                            return;
                        (k.layout || "").split(",").forEach(function (l) {
                            var t = String(l).trim();
                            if (t && arr.indexOf(t) === -1)
                                arr.push(t);
                        });
                        active = k.active_keymap;
                    });
                    hyprKeyboardLayoutImpl.update(arr, active);
                } catch (e) {
                    console.error("[HyprKeyboardLayoutImpl] parse error:", e);
                }
            }
        }
    }

    // Listen to hyprland raw events
    Connections {
        target: hyprKeyboardLayoutImpl.enabled ? Hyprland : null
        enabled: hyprKeyboardLayoutImpl.enabled
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            var parts = String(event.data || "").split(",").map(function (t) {
                return t.trim();
            });
            hyprKeyboardLayoutImpl.update(parts, parts[parts.length - 1]);
        }
    }
}
