pragma Singleton
import Quickshell
import QtQuick
import qs.Services.WM as WM

// WallpaperService keeps only wallpaper-related preferences per monitor.
// Monitor geometry and state are sourced directly from MonitorService.
Singleton {
    id: wallpaperService

    property var monitorService: WM.MonitorService
    property bool ready: false

    // Default wallpaper and default mode applied when no preference exists
    property string defaultWallpaper: "/home/anas/Pictures/3.jpg"
    property string defaultMode: "fill" // fill | fit | center, etc.

    // Preferences keyed by monitor name
    // { [name]: { wallpaper: string, mode: string, dir?: string, random?: bool, interval?: int } }
    property var prefsByName: ({})

    // Per-monitor cached file lists for random rotation (dir -> files)
    property var filesByName: ({})

    // Per-monitor timers for random rotation
    property var timersByName: ({})

    // Derived view for UI: combine MonitorService geometry with wallpaper prefs
    readonly property var wallpapersArray: Array.from({
        length: monitorService && monitorService.ready ? monitorService.monitorsModel.count : 0
    }, (_, i) => {
        const m = monitorService.monitorsModel.get(i);
        const p = prefsByName[m.name] || {};
        return {
            name: m.name,
            width: m.width,
            height: m.height,
            scale: m.scale,
            fps: m.fps,
            bitDepth: m.bitDepth,
            orientation: m.orientation,
            wallpaper: p.wallpaper || defaultWallpaper,
            mode: p.mode || defaultMode
        };
    })

    // Helper: get or create prefs for a monitor name
    function ensurePrefs(name) {
        if (!prefsByName.hasOwnProperty(name)) {
            prefsByName[name] = {
                wallpaper: defaultWallpaper,
                mode: defaultMode,
                random: false,
                interval: 300 // seconds
            };
        }
        return prefsByName[name];
    }

    // Helper: get wallpapers entry for name or screen object
    function wallpaperFor(nameOrScreen) {
        const name = typeof nameOrScreen === "string" ? nameOrScreen : (nameOrScreen && nameOrScreen.name) || null;
        if (!name)
            return null;
        const idx = monitorService ? monitorService.findMonitorIndexByName(name) : -1;
        if (idx < 0)
            return null;
        const m = monitorService.monitorsModel.get(idx);
        const p = prefsByName[name] || {};
        return {
            name: name,
            width: m.width,
            height: m.height,
            scale: m.scale,
            fps: m.fps,
            bitDepth: m.bitDepth,
            orientation: m.orientation,
            wallpaper: p.wallpaper || defaultWallpaper,
            mode: p.mode || defaultMode
        };
    }

    // Sync prefs and timers with current monitors
    function syncWithMonitors() {
        if (!monitorService || !monitorService.ready) {
            ready = false;
            return;
        }

        // Add defaults for new monitors and ensure timers
        for (let i = 0; i < monitorService.monitorsModel.count; i++) {
            const m = monitorService.monitorsModel.get(i);
            ensurePrefs(m.name);
            ensureTimer(m.name);
        }

        // Remove prefs/timers for monitors that no longer exist
        const existingNames = Object.keys(prefsByName);
        for (let j = 0; j < existingNames.length; j++) {
            const name = existingNames[j];
            const idx = monitorService.findMonitorIndexByName(name);
            if (idx < 0) {
                delete prefsByName[name];
                destroyTimer(name);
                delete filesByName[name];
            }
        }

        // Apply timer state from prefs
        for (let k = 0; k < monitorService.monitorsModel.count; k++) {
            const m = monitorService.monitorsModel.get(k);
            applyRandomState(m.name);
        }

        ready = monitorService.monitorsModel.count > 0;
    }

    // Timers
    function ensureTimer(name) {
        if (timersByName[name])
            return timersByName[name];
        const t = Qt.createQmlObject('import QtQuick; Timer { repeat: true; running: false; property string nameKey: ""; onTriggered: wallpaperService.rotateRandom(nameKey) }', wallpaperService);
        t.nameKey = name;
        timersByName[name] = t;
        return t;
    }
    function destroyTimer(name) {
        const t = timersByName[name];
        if (t) {
            try {
                t.running = false;
            } catch (e) {}
            t.destroy();
        }
        delete timersByName[name];
    }
    function applyRandomState(name) {
        const p = ensurePrefs(name);
        const t = ensureTimer(name);
        t.interval = Math.max(1, (p.interval || 300)) * 1000;
        t.running = !!p.random;
    }

    // API: set wallpaper/mode for a monitor
    function setWallpaper(nameOrScreen, path) {
        const name = typeof nameOrScreen === "string" ? nameOrScreen : (nameOrScreen && nameOrScreen.name) || null;
        if (!name)
            return;
        const p = ensurePrefs(name);
        p.wallpaper = path || defaultWallpaper;
        // Optional: restart random timer when manual change occurs
        const t = timersByName[name];
        if (t && t.running) {
            t.restart();
        }
    }
    function setModePref(name, mode) {
        const p = ensurePrefs(name);
        p.mode = mode || defaultMode;
    }

    // API: random rotation controls (per monitor)
    function setRandomEnabled(name, enabled) {
        const p = ensurePrefs(name);
        p.random = !!enabled;
        applyRandomState(name);
    }
    function setRandomInterval(name, seconds) {
        const p = ensurePrefs(name);
        p.interval = seconds > 0 ? seconds : 300;
        applyRandomState(name);
    }
    function setRandomDirectory(name, dir, files) {
        const p = ensurePrefs(name);
        p.dir = dir || "";
        // Caller provides files discovered for dir (no swww). You can also scan here if desired.
        filesByName[name] = Array.isArray(files) ? files : [];
    }
    function rotateRandom(name) {
        const list = filesByName[name] || [];
        if (!list.length)
            return;
        const idx = Math.floor(Math.random() * list.length);
        setWallpaper(name, list[idx]);
    }

    // Forward monitor-related changes to MonitorService (do not mirror geometry here)
    function changeMonitorSettings(settings) {
        if (monitorService && monitorService.changeMonitorSettings)
            monitorService.changeMonitorSettings(settings);
    }
    function setScale(name, scale) {
        if (monitorService && monitorService.setScale)
            monitorService.setScale(name, scale);
    }
    function setMode(name, w, h, rr) {
        if (monitorService && monitorService.setMode)
            monitorService.setMode(name, w, h, rr);
    }
    function setTransform(name, transform) {
        if (monitorService && monitorService.setTransform)
            monitorService.setTransform(name, transform);
    }
    function setPosition(name, x, y) {
        if (monitorService && monitorService.setPosition)
            monitorService.setPosition(name, x, y);
    }
    function setVrr(name, mode) {
        if (monitorService && monitorService.setVrr)
            monitorService.setVrr(name, mode);
    }

    // React to monitor service readiness and changes
    Connections {
        target: wallpaperService.monitorService
        function onReadyChanged() {
            if (wallpaperService.monitorService.ready) {
                wallpaperService.syncWithMonitors();
            } else {
                wallpaperService.ready = false;
            }
        }
        function onMonitorsChanged() {
            if (wallpaperService.monitorService.ready) {
                wallpaperService.syncWithMonitors();
            }
        }
    }

    Component.onCompleted: {
        if (monitorService && monitorService.ready) {
            syncWithMonitors();
        }
    }
}
