pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import qs.Services as Services

Singleton {
    id: root

    // Toggle to start/stop processes
    property bool enabled: false
    readonly property bool active: (Services.MainService.currentWM === "niri")

    // Public API mirrored by the service
    property var layouts: []
    property string currentLayout: ""

    function setLayoutByIndex(layoutIndex) {
        root.currentLayout = root.layouts[layoutIndex] || "";
    }

    Process {
        id: layoutSeedProcess
        running: root.enabled && root.active
        command: ["niri", "msg", "--json", "keyboard-layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                var data = JSON.parse(text);
                root.layouts = data.names || [];
                root.setLayoutByIndex(data.current_idx);
            }
        }
    }

    Process {
        id: eventStreamProcess
        running: root.enabled && root.active
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (segment) {
                if (!segment)
                    return;
                var event = JSON.parse(segment);
                if (event.KeyboardLayoutsChanged) {
                    var layoutInfo = event.KeyboardLayoutsChanged.keyboard_layouts;
                    root.layouts = layoutInfo.names || [];
                    root.setLayoutByIndex(layoutInfo.current_idx);
                } else if (event.KeyboardLayoutSwitched) {
                    var layoutIndex = event.KeyboardLayoutSwitched.idx;
                    root.setLayoutByIndex(layoutIndex);
                }
            }
        }
    }
}
