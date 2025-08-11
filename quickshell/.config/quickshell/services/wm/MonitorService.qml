pragma Singleton
import Quickshell
import QtQml
import QtQuick
import "../" as Services

Singleton {
    id: monitorService

    property var mainService: Services.MainService
    property ListModel monitorsModel: ListModel {}
    property var impl: null
    property bool ready: false

    Connections {
        target: monitorService.mainService
        function onReadyChanged() {
            if (monitorService.mainService.ready) {
                monitorService.setupImpl();
            }
        }
    }

    Component.onCompleted: {
        if (monitorService.mainService.ready) {
            setupImpl();
        }
    }

    function setupImpl() {
        // Start with Quickshell.screens
        updateMonitors(Quickshell.screens);

        // Hook WM-specific impl
        if (monitorService.mainService.currentWM === "hyprland") {
            monitorService.impl = Services.HyprMonitorService;
        } else if (monitorService.mainService.currentWM === "niri") {
            monitorService.impl = Services.NiriMonitorService;
        }

        // Merge WM-specific info if available
        if (monitorService.impl && monitorService.impl.monitorsChanged) {
            monitorService.impl.monitorsChanged.connect(() => {
                const newList = monitorService.impl.monitors.length ? monitorService.impl.monitors : Quickshell.screens;
                updateMonitors(newList);
            });
        }

        monitorService.ready = true;
        console.log("[MonitorService] Ready with", monitorsModel.count, "monitors");
    }

    function updateMonitors(newList) {
        monitorsModel.clear();
        for (let m of newList) {
            monitorsModel.append({
                name: m.name,
                width: m.width,
                height: m.height,
                scale: m.devicePixelRatio || 1,
                fps: m.refreshRate || 60,
                bitDepth: m.colorDepth || 8,
                orientation: m.orientation
            });
        }
    }
}
