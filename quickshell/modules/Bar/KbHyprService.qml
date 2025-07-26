import QtQuick
import Quickshell.Hyprland
import Quickshell
import Quickshell.Io

Item {
    id: kbHyprService

    property var layouts: []
    property string currentLayout: ""
    property bool available: false

    function shortName(full) {
        if (!full)
            return "";
        var lang = full.trim().split(" ")[0];
        return lang.substring(0, 2).toUpperCase();
    }

    function update(layoutsArr, activeFull) {
        layouts = layoutsArr.map(function (x) {
            return x.trim();
        });
        available = layouts.length > 1;
        var full = activeFull ? activeFull.trim() : (layouts[layouts.length - 1] || "");
        currentLayout = full;
    }

    function seedInitial() {
        seedProc.running = true;
    }

    Process {
        id: seedProc
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(text);
                    var arr = [], active = "";
                    j.keyboards.forEach(function (k) {
                        if (!k.main)
                            return;
                        k.layout.split(",").forEach(function (l) {
                            var t = l.trim();
                            if (arr.indexOf(t) === -1)
                                arr.push(t);
                        });
                        active = k.active_keymap;
                    });
                    kbHyprService.update(arr, active);
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            var parts = event.data.split(",");
            kbHyprService.update(parts, parts[parts.length - 1]);
        }
    }
}
