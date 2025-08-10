pragma Singleton
import Quickshell
import QtQuick
import "../" as Services

Singleton {
    id: monitorService

    property var mainService: Services.MainService
    property var monitors: []
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
        // Wrap Quickshell.screens into objects with safe scale
        monitorService.monitors = Quickshell.screens.map(s => ({
                    name: s.name,
                    implicitWidth: s.width,
                    implicitWidth: s.height,
                    scale: s.devicePixelRatio || 1,
                    orientation: s.orientation
                }));

        if (monitorService.mainService.currentWM === "hyprland") {
            monitorService.impl = Services.HyprMonitorService;
        } else if (monitorService.mainService.currentWM === "niri") {
            monitorService.impl = Services.NiriMonitorService;
        }

        if (monitorService.impl && monitorService.impl.monitorsChanged) {
            monitorService.impl.monitorsChanged.connect(() => {
                monitorService.monitors = monitorService.impl.monitors.length ? monitorService.impl.monitors : Quickshell.screens.map(s => ({
                            name: s.name,
                            width: s.width,
                            height: s.height,
                            scale: s.devicePixelRatio || 1,
                            orientation: s.orientation
                        }));
            });
        }

        monitorService.ready = true;
        console.log("[MonitorService] Ready with", monitorService.monitors.length, "monitors");
    }
}
