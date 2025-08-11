pragma Singleton
import Quickshell
import QtQuick
import "../" as Services

Singleton {
    id: wallpaperService

    property var monitorService: Services.MonitorService
    property bool ready: false

    property var wallpaperMap: ({
            "HDMI-A-1": "/home/anas/Pictures/3.jpg",
            "eDP-1": "/home/anas/Pictures/3.jpg"
        })

    property var wallpapers: []

    Connections {
        target: monitorService
        function onReadyChanged() {
            if (monitorService.ready) {
                recomputeWallpapers();
            } else {
                ready = false;
            }
        }
    }

    Connections {
        target: monitorService.monitorsModel
        function onCountChanged() {
            if (monitorService.ready) {
                recomputeWallpapers();
            }
        }
    }

    function recomputeWallpapers() {
        wallpapers = [];
        for (let i = 0; i < monitorService.monitorsModel.count; i++) {
            const m = monitorService.monitorsModel.get(i);
            wallpapers.push({
                name: m.name,
                width: m.width,
                height: m.height,
                scale: m.scale,
                fps: m.fps,
                bitDepth: m.bitDepth,
                orientation: m.orientation,
                wallpaper: wallpaperMap[m.name] || "/home/anas/Pictures/3.jpg",
                mode: "fill"
            });
        }

        ready = wallpapers.length > 0 && wallpapers.every(w => w.width && w.height && w.scale);

        console.log("[WallpaperService] Wallpapers updated:", wallpapers.length);
        wallpapers.forEach(w => {
            console.log(`  - ${w.name}: ${w.width}x${w.height} @${w.scale}x → ${w.wallpaper}`);
        });
    }

    Component.onCompleted: {
        if (monitorService.ready) {
            recomputeWallpapers();
        } else {
            console.log("[WallpaperService] Waiting for MonitorService to be ready...");
        }
    }
}
