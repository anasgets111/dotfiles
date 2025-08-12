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
    function wallpaperFor(nameOrScreen) {
        const name = typeof nameOrScreen === "string" ? nameOrScreen : (nameOrScreen && nameOrScreen.name) || null;

        if (!name)
            return null;

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

        for (let i = 0; i < monitorCount; i++) {
            const m = monitorService.monitorsModel.get(i);
        }

        // Update existing monitors
        const minCount = Math.min(monitorCount, wallpaperCount);
        for (let i = 0; i < minCount; i++) {
            const m = monitorService.monitorsModel.get(i);

            if (m.name && !wallpaperMap.hasOwnProperty(m.name)) {
                wallpaperMap[m.name] = defaultWallpaper;
            }

            const newWallpaper = wallpaperMap[m.name] || defaultWallpaper;

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
            for (let i = wallpaperCount - 1; i >= monitorCount; i--) {
                wallpapersModel.remove(i);
            }
        }

        // Add new monitors
        if (monitorCount > wallpaperCount) {
            for (let i = wallpaperCount; i < monitorCount; i++) {
                const m = monitorService.monitorsModel.get(i);

                if (m.name && !wallpaperMap.hasOwnProperty(m.name)) {
                    wallpaperMap[m.name] = defaultWallpaper;
                }

                const newWallpaper = wallpaperMap[m.name] || defaultWallpaper;

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

        for (let i = 0; i < wallpapersModel.count; i++) {
            const w = wallpapersModel.get(i);
        }
    }

    Component.onCompleted: {
        if (monitorService.ready) {
            syncWallpapersWithMonitors();
        }
    }
}
