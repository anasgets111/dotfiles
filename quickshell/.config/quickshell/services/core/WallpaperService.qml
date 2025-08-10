pragma Singleton
import Quickshell
import QtQuick
import "../" as Services

Singleton {
    id: wallpaperService

    property var monitorService: Services.MonitorService
    property bool ready: false

    // Map of monitor name → wallpaper path
    // You can later load this from a config file
    property var wallpaperMap: ({
            "HDMI-A-1": "/home/anas/Pictures/3.jpg",
            "eDP-1": "/home/anas/Pictures/3.jpg"
        })

    // Wallpapers list is bound to monitorService.monitors when ready
    property var wallpapers: (monitorService && monitorService.ready) ? monitorService.monitors.map(m => ({
                name: m.name,
                width: m.width,
                height: m.height,
                scale: m.scale,
                orientation: m.orientation,
                wallpaper: wallpaperMap[m.name] || "/home/anas/Pictures/default.jpg",
                mode: "fill"
            })) : []

    onWallpapersChanged: {
        if (monitorService && monitorService.ready) {
            ready = wallpapers.length > 0;
            console.log("[WallpaperService] Wallpapers updated:", wallpapers.length);
            wallpapers.forEach(w => {
                console.log(`  - ${w.name}: ${w.width}x${w.height} @${w.scale}x → ${w.wallpaper}`);
            });
        } else {
            ready = false;
        }
    }

    Component.onCompleted: {
        if (!monitorService.ready) {
            console.log("[WallpaperService] Waiting for MonitorService to be ready...");
        } else {
            ready = wallpapers.length > 0;
        }
    }
}
