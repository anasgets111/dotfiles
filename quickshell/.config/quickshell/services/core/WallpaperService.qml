pragma Singleton
import Quickshell
import QtQuick
import "../" as Services

Singleton {
    id: wallpaperService

    property var monitorService: Services.MonitorService
    property bool ready: false

    // Internal model for per-item updates
    property ListModel wallpapersModel: ListModel {}

    // Computed array view for frontend
    readonly property var wallpapersArray: Array.from({
        length: wallpapersModel.count
    }, (_, i) => wallpapersModel.get(i))

    property var wallpaperMap: ({})

    Connections {
        target: wallpaperService.monitorService
        function onReadyChanged() {
            if (wallpaperService.monitorService.ready) {
                wallpaperService.syncWallpapersWithMonitors();
            } else {
                wallpaperService.ready = false;
            }
        }
        function onMonitorsChanged() {
            if (wallpaperService.monitorService.ready) {
                wallpaperService.syncWallpapersWithMonitors();
            }
        }
    }
    function wallpaperFor(name) {
        for (let i = 0; i < wallpapersModel.count; i++) {
            const w = wallpapersModel.get(i);
            if (w.name === name)
                return w;
        }
        return null;
    }
    function syncWallpapersWithMonitors() {
        const monitorCount = monitorService.monitorsModel.count;
        const wallpaperCount = wallpapersModel.count;
        const defaultWallpaper = "/home/anas/Pictures/3.jpg";

        console.log("[WallpaperService] --- Sync Start ---");
        console.log(`[WallpaperService] Monitors detected: ${monitorCount}`);
        for (let i = 0; i < monitorCount; i++) {
            const m = monitorService.monitorsModel.get(i);
            console.log(`  Monitor[${i}]: name=${m.name}, size=${m.width}x${m.height}`);
        }

        // Update existing monitors
        const minCount = Math.min(monitorCount, wallpaperCount);
        for (let i = 0; i < minCount; i++) {
            const m = monitorService.monitorsModel.get(i);

            if (m.name && !wallpaperMap.hasOwnProperty(m.name)) {
                console.log(`[WallpaperService] Monitor ${m.name} not in wallpaperMap → adding default`);
                wallpaperMap[m.name] = defaultWallpaper;
            } else {
                console.log(`[WallpaperService] Monitor ${m.name} already in wallpaperMap`);
            }

            const newWallpaper = wallpaperMap[m.name] || defaultWallpaper;
            console.log(`[WallpaperService] Assigning wallpaper to ${m.name}: ${newWallpaper}`);

            const w = wallpapersModel.get(i);
            wallpapersModel.set(i, {
                name: m.name,
                width: m.width,
                height: m.height,
                scale: m.scale,
                fps: m.fps,
                bitDepth: m.bitDepth,
                orientation: m.orientation,
                wallpaper: newWallpaper,
                mode: "fill"
            });
        }

        // Remove extra wallpapers
        if (wallpaperCount > monitorCount) {
            console.log(`[WallpaperService] Removing ${wallpaperCount - monitorCount} extra wallpapers`);
            for (let i = wallpaperCount - 1; i >= monitorCount; i--) {
                wallpapersModel.remove(i);
            }
        }

        // Add new monitors
        if (monitorCount > wallpaperCount) {
            console.log(`[WallpaperService] Adding ${monitorCount - wallpaperCount} new wallpapers`);
            for (let i = wallpaperCount; i < monitorCount; i++) {
                const m = monitorService.monitorsModel.get(i);

                if (m.name && !wallpaperMap.hasOwnProperty(m.name)) {
                    console.log(`[WallpaperService] Monitor ${m.name} not in wallpaperMap → adding default`);
                    wallpaperMap[m.name] = defaultWallpaper;
                } else {
                    console.log(`[WallpaperService] Monitor ${m.name} already in wallpaperMap`);
                }

                const newWallpaper = wallpaperMap[m.name] || defaultWallpaper;
                console.log(`[WallpaperService] Assigning wallpaper to ${m.name}: ${newWallpaper}`);

                wallpapersModel.append({
                    name: m.name,
                    width: m.width,
                    height: m.height,
                    scale: m.scale,
                    fps: m.fps,
                    bitDepth: m.bitDepth,
                    orientation: m.orientation,
                    wallpaper: newWallpaper,
                    mode: "fill"
                });
            }
        }

        // Ready state
        ready = wallpapersModel.count > 0 && Array.from({
            length: wallpapersModel.count
        }, (_, i) => wallpapersModel.get(i)).every(w => w.width && w.height && w.scale);

        console.log(`[WallpaperService] Ready: ${ready}`);
        console.log("[WallpaperService] wallpapersModel after sync:");
        for (let i = 0; i < wallpapersModel.count; i++) {
            const w = wallpapersModel.get(i);
            console.log(`  - ${w.name}: ${w.wallpaper}`);
        }
        console.log("[WallpaperService] --- Sync End ---");
    }

    Component.onCompleted: {
        if (monitorService.ready) {
            syncWallpapersWithMonitors();
        } else {
            console.log("[WallpaperService] Waiting for MonitorService to be ready...");
        }
    }
}
