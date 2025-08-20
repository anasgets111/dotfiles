pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import qs.Services

Singleton {
    id: root

    readonly property bool active: MainService.ready && MainService.currentWM === "niri"
    property bool enabled: root.active

    property var layouts: []
    property string currentLayout: ""

    function setLayoutByIndex(layoutIndex) {
        root.currentLayout = root.layouts && layoutIndex >= 0 && layoutIndex < root.layouts.length ? (root.layouts[layoutIndex] || "") : "";
    }

    Process {
        id: layoutSeedProcess
        running: root.enabled
        command: ["niri", "msg", "--json", "keyboard-layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text || "{}");
                    root.layouts = (data && data.names) ? data.names : [];
                    const idx = (data && typeof data.current_idx === "number") ? data.current_idx : -1;
                    root.setLayoutByIndex(idx);
                } catch (e) {
                    MainService.logger.log("KeyboardLayoutImpl(Niri)", "Failed to parse keyboard-layouts JSON:", e.toString());
                }
            }
        }
    }

    Process {
        id: eventStreamProcess
        running: root.enabled
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (segment) {
                if (!segment)
                    return;
                try {
                    const event = JSON.parse(segment);
                    if (event && event.KeyboardLayoutsChanged) {
                        const layoutInfo = event.KeyboardLayoutsChanged.keyboard_layouts || {};
                        root.layouts = layoutInfo.names || [];
                        const idx = typeof layoutInfo.current_idx === "number" ? layoutInfo.current_idx : -1;
                        root.setLayoutByIndex(idx);
                    } else if (event && event.KeyboardLayoutSwitched) {
                        const layoutIndex = event.KeyboardLayoutSwitched.idx;
                        if (typeof layoutIndex === "number")
                            root.setLayoutByIndex(layoutIndex);
                    }
                } catch (e) {
                    MainService.logger.log("KeyboardLayoutImpl(Niri)", "Failed to parse event-stream JSON:", e.toString());
                }
            }
        }
    }
}
