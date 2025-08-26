pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import qs.Services.Utils
import qs.Services

Singleton {
    id: impl

    readonly property bool active: MainService.ready && MainService.currentWM === "hyprland"

    property var layouts: []
    property string currentLayout: ""

    function buildLayoutsFromDevices(jsonText) {
        const clean = Utils.stripAnsi(jsonText || "").trim();
        const data = Utils.safeJsonParse(clean, {});
        const keyboards = (data && data.keyboards) || [];
        const unique = [];
        let active = "";

        for (let i = 0; i < keyboards.length; i++) {
            const kb = keyboards[i];
            if (!kb || !kb.main)
                continue;

            const layoutStr = kb.layout || "";
            if (layoutStr) {
                const parts = layoutStr.split(",").map(s => (s || "").trim()).filter(Boolean);
                for (let j = 0; j < parts.length; j++) {
                    const name = parts[j];
                    if (unique.indexOf(name) === -1)
                        unique.push(name);
                }
            }
            if (kb.active_keymap)
                active = kb.active_keymap;
        }

        return {
            unique,
            active
        };
    }

    Process {
        id: layoutSeedProcess
        running: impl.active
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!impl.active)
                    return;
                try {
                    const {
                        unique,
                        active
                    } = impl.buildLayoutsFromDevices(text);
                    impl.layouts = unique;
                    impl.currentLayout = active || "";
                } catch (e) {
                    Logger.log("KeyboardLayoutImpl(Hypr)", "Failed to parse devices JSON:", String(e));
                }
            }
        }
    }

    Connections {
        target: impl.active ? Hyprland : null
        function onRawEvent(event) {
            if (!event || event.name !== "activelayout")
                return;
            const payload = typeof event.data === "string" ? event.data : "";
            if (!payload)
                return;

            // payload e.g. "us,us-intl,ara,ara(mac)" -> last entry is active
            const parts = payload.split(",").map(s => (s || "").trim()).filter(Boolean);
            if (parts.length === 0)
                return;

            impl.layouts = parts;
            impl.currentLayout = parts[parts.length - 1] || "";
        }
    }
}
