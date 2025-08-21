pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import qs.Services.Utils
import qs.Services

Singleton {
    id: root

    readonly property bool active: MainService.ready && MainService.currentWM === "hyprland"
    property bool enabled: root.active
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
                try {
                    const clean = Utils.stripAnsi(text || "").trim();
                    const data = Utils.safeJsonParse(clean, {});
                    const layoutArray = [];
                    let activeLayout = "";
                    const keyboards = (data && data.keyboards) ? data.keyboards : [];
                    keyboards.forEach(function (keyboard) {
                        if (!keyboard || !keyboard.main)
                            return;
                        const kLayouts = (keyboard.layout || "").split(",");
                        kLayouts.forEach(function (layout) {
                            const trimmedLayout = (layout || "").trim();
                            if (trimmedLayout && layoutArray.indexOf(trimmedLayout) === -1)
                                layoutArray.push(trimmedLayout);
                        });
                        if (keyboard.active_keymap)
                            activeLayout = keyboard.active_keymap;
                    });
                    root.layouts = layoutArray;
                    root.currentLayout = activeLayout || "";
                } catch (e) {
                    // Avoid crashing on bad hyprctl output; leave previous state
                    Logger.log("KeyboardLayoutImpl(Hypr)", "Failed to parse devices JSON:", e.toString());
                }
            }
        }
    }

    Connections {
        target: root.enabled ? Hyprland : null
        enabled: root.enabled
        function onRawEvent(event) {
            if (!event || event.name !== "activelayout")
                return;
            const payload = (event.data || "");
            if (typeof payload !== "string")
                return;
            const layoutParts = payload.split(",").map(function (part) {
                return (part || "").trim();
            }).filter(function (p) {
                return !!p;
            });
            if (layoutParts.length === 0)
                return;
            root.layouts = layoutParts;
            root.currentLayout = layoutParts[layoutParts.length - 1] || "";
        }
    }
}
