pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import qs.Services.Utils
import qs.Services

Singleton {
    id: root

    readonly property bool active: MainService.ready && MainService.currentWM === "niri"
    property bool enabled: root.active

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""

    property var layouts: []
    property string currentLayout: ""

    function setLayoutByIndex(layoutIndex) {
        root.currentLayout = root.layouts && layoutIndex >= 0 && layoutIndex < root.layouts.length ? (root.layouts[layoutIndex] || "") : "";
    }

    // Event stream via IPC socket (no CLI fallback)
    Socket {
        id: eventStreamSocket
        path: root.socketPath
        connected: root.enabled && !!root.socketPath

        onConnectionStateChanged: {
            if (connected) {
                write('"EventStream"\n');
            }
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function (segment) {
                if (!segment)
                    return;
                const event = Utils.safeJsonParse(segment, null);
                if (!event)
                    return;
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
            }
        }
    }
}
