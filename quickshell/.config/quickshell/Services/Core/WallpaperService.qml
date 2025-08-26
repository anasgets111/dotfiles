pragma Singleton
import Quickshell
import QtQuick
import qs.Services.WM
import qs.Services.Utils

Singleton {
    id: wallpaperService

    readonly property bool ready: !!(MonitorService.ready && MonitorService.monitors.count > 0)

    property string defaultWallpaper: "/mnt/Work/1Wallpapers/Main/samurai.jpg"
    property string defaultMode: "fill" // fill | fit | center, etc.

    // { [name]: { wallpaper: string, mode: string, dir?: string, random?: bool, interval?: int } }
    property var prefsByName: ({})
    property var filesByName: ({})
    property var timersByName: ({})

    readonly property var wallpapersArray: Array.from({
        length: MonitorService.ready ? MonitorService.monitors.count : 0
    }, (unusedValue, monitorIndex) => {
        const monitor = MonitorService.monitors.get(monitorIndex);
        const prefs = prefsByName[monitor.name] || {};
        return {
            name: monitor.name,
            width: monitor.width,
            height: monitor.height,
            scale: monitor.scale,
            fps: monitor.fps,
            bitDepth: monitor.bitDepth,
            orientation: monitor.orientation,
            wallpaper: prefs.wallpaper || defaultWallpaper,
            mode: prefs.mode || defaultMode
        };
    })

    function ensurePrefs(name) {
        if (!prefsByName.hasOwnProperty(name)) {
            prefsByName[name] = {
                wallpaper: defaultWallpaper,
                mode: defaultMode,
                random: false,
                interval: 300
            };
        }
        return prefsByName[name];
    }

    function wallpaperFor(nameOrScreen) {
        const name = typeof nameOrScreen === "string" ? nameOrScreen : (nameOrScreen && nameOrScreen.name) || null;
        if (!name)
            return null;
        const monitorIndex = MonitorService ? MonitorService.findMonitorIndexByName(name) : -1;
        if (monitorIndex < 0)
            return null;
        const monitor = MonitorService.monitors.get(monitorIndex);
        const prefs = prefsByName[name] || {};
        return {
            name: name,
            width: monitor.width,
            height: monitor.height,
            scale: monitor.scale,
            fps: monitor.fps,
            bitDepth: monitor.bitDepth,
            orientation: monitor.orientation,
            wallpaper: prefs.wallpaper || defaultWallpaper,
            mode: prefs.mode || defaultMode
        };
    }

    function syncWithMonitors() {
        if (!MonitorService || !MonitorService.ready) {
            Logger.log("WallpaperService", "sync: monitorService not ready; skipping");
            return;
        }
        Logger.log("WallpaperService", "sync: begin");

        for (let monitorIndex = 0; monitorIndex < MonitorService.monitors.count; monitorIndex++) {
            const monitor = MonitorService.monitors.get(monitorIndex);
            ensurePrefs(monitor.name);
            ensureTimer(monitor.name);
        }

        const existingNames = Object.keys(prefsByName);
        for (let nameIndex = 0; nameIndex < existingNames.length; nameIndex++) {
            const name = existingNames[nameIndex];
            const monitorIndex = MonitorService.findMonitorIndexByName(name);
            if (monitorIndex < 0) {
                delete prefsByName[name];
                destroyTimer(name);
                delete filesByName[name];
                Logger.log("WallpaperService", `Removed stale monitor prefs/timer: ${name}`);
            }
        }

        for (let monitorIndex = 0; monitorIndex < MonitorService.monitors.count; monitorIndex++) {
            const monitor = MonitorService.monitors.get(monitorIndex);
            applyRandomState(monitor.name);
        }

        Logger.log("WallpaperService", `sync: done; monitors=${MonitorService.monitors.count}, prefs=${Object.keys(prefsByName).length}`);
    }

    function ensureTimer(name) {
        if (timersByName[name])
            return timersByName[name];
        const timer = Qt.createQmlObject('import QtQuick; Timer { repeat: true; running: false; property string nameKey: ""; onTriggered: wallpaperService.rotateRandom(nameKey) }', wallpaperService);
        timer.nameKey = name;
        timersByName[name] = timer;
        Logger.log("WallpaperService", `Timer created for monitor: ${name}`);
        return timer;
    }
    function destroyTimer(name) {
        const timer = timersByName[name];
        if (timer) {
            try {
                timer.running = false;
            } catch (error) {}
            timer.destroy();
            Logger.log("WallpaperService", `Timer destroyed for monitor: ${name}`);
        }
        delete timersByName[name];
    }
    function applyRandomState(name) {
        const prefs = ensurePrefs(name);
        const timer = ensureTimer(name);
        timer.interval = Math.max(1, (prefs.interval || 300)) * 1000;
        timer.running = !!prefs.random;
        Logger.log("WallpaperService", `Random ${timer.running ? 'enabled' : 'disabled'} for ${name}; interval=${timer.interval}ms`);
    }

    function setWallpaper(nameOrScreen, path) {
        const name = typeof nameOrScreen === "string" ? nameOrScreen : (nameOrScreen && nameOrScreen.name) || null;
        if (!name)
            return;
        const prefs = ensurePrefs(name);
        prefs.wallpaper = path || defaultWallpaper;
        Logger.log("WallpaperService", `Set wallpaper: name=${name}, path=${prefs.wallpaper}`);
        const timer = timersByName[name];
        if (timer && timer.running) {
            timer.restart();
        }
    }
    function setModePref(name, mode) {
        const prefs = ensurePrefs(name);
        prefs.mode = mode || defaultMode;
        Logger.log("WallpaperService", `Set mode: name=${name}, mode=${prefs.mode}`);
    }

    function setRandomEnabled(name, enabled) {
        const prefs = ensurePrefs(name);
        prefs.random = !!enabled;
        applyRandomState(name);
    }
    function setRandomInterval(name, seconds) {
        const prefs = ensurePrefs(name);
        prefs.interval = seconds > 0 ? seconds : 300;
        applyRandomState(name);
    }
    function setRandomDirectory(name, directory, files) {
        const prefs = ensurePrefs(name);
        prefs.dir = directory || "";
        filesByName[name] = Array.isArray(files) ? files : [];
        Logger.log("WallpaperService", `Set random dir: name=${name}, dir=${prefs.dir}, files=${filesByName[name].length}`);
    }
    function rotateRandom(name) {
        const filesForMonitor = filesByName[name] || [];
        if (!filesForMonitor.length)
            return;
        const randomIndex = Math.floor(Math.random() * filesForMonitor.length);
        const chosenFile = filesForMonitor[randomIndex];
        Logger.log("WallpaperService", `Rotate random: name=${name}, chosen=${chosenFile}`);
        setWallpaper(name, chosenFile);
    }

    function changeMonitorSettings(settings) {
        if (MonitorService && MonitorService.applySettings)
            MonitorService.applySettings(settings);
    }
    function setScale(name, scale) {
        if (MonitorService && MonitorService.setScale)
            MonitorService.setScale(name, scale);
    }
    function setMode(name, width, height, refreshRate) {
        if (MonitorService && MonitorService.setMode)
            MonitorService.setMode(name, width, height, refreshRate);
    }
    function setTransform(name, transform) {
        if (MonitorService && MonitorService.setTransform)
            MonitorService.setTransform(name, transform);
    }
    function setPosition(name, positionX, positionY) {
        if (MonitorService && MonitorService.setPosition)
            MonitorService.setPosition(name, positionX, positionY);
    }
    function setVrr(name, mode) {
        if (MonitorService && MonitorService.setVrr)
            MonitorService.setVrr(name, mode);
    }

    Connections {
        target: MonitorService
        function onReadyChanged() {
            if (MonitorService.ready) {
                Logger.log("WallpaperService", "MonitorService ready");
                wallpaperService.syncWithMonitors();
            } else {
                Logger.log("WallpaperService", "MonitorService not ready");
            }
        }
        function onMonitorsUpdated() {
            if (MonitorService.ready) {
                Logger.log("WallpaperService", "Monitors changed; syncing");
                wallpaperService.syncWithMonitors();
            }
        }
    }

    Component.onCompleted: {
        if (MonitorService.ready) {
            Logger.log("WallpaperService", "Init: MonitorService ready; syncing");
            syncWithMonitors();
        } else {
            Logger.log("WallpaperService", "Init: MonitorService not ready yet");
        }
    }
}
