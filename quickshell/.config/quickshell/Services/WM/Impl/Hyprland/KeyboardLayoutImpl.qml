pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property bool enabled: false
    property var layouts: []
    property string currentLayout: ""

    Process {
        id: layoutSeedProcess
        running: root.enabled
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.enabled)
                    return;
                var data = JSON.parse(text);
                var layoutArray = [], activeLayout = "";
                data.keyboards.forEach(function (keyboard) {
                    if (!keyboard.main)
                        return;
                    (keyboard.layout || "").split(",").forEach(function (layout) {
                        var trimmedLayout = layout.trim();
                        if (trimmedLayout && layoutArray.indexOf(trimmedLayout) === -1)
                            layoutArray.push(trimmedLayout);
                    });
                    activeLayout = keyboard.active_keymap;
                });
                root.layouts = layoutArray;
                root.currentLayout = activeLayout || "";
            }
        }
    }

    Connections {
        target: root.enabled ? Hyprland : null
        enabled: root.enabled
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            var layoutParts = (event.data || "").split(",").map(function (part) {
                return part.trim();
            });
            root.layouts = layoutParts;
            root.currentLayout = layoutParts[layoutParts.length - 1] || "";
        }
    }
}
