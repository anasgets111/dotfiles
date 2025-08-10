pragma Singleton
import QtQuick
import Quickshell
import "../wm" as WM

Singleton {
    id: wallpaperService
    property var wallpapers: []
    property var monitorService: WM.MonitorService

    Component.onCompleted: {
        updateFromMonitors();
        monitorService.monitorsChanged.connect(updateFromMonitors);
    }

    function updateFromMonitors() {
        wallpapers = monitorService.monitors.map(m => ({
                    name: m.name,
                    width: m.width,
                    height: m.height,
                    scale: m.scale,
                    orientation: m.orientation,
                    wallpaper: "/usr/share/backgrounds/default.jpg",
                    mode: "fill"
                }));
    }
}
