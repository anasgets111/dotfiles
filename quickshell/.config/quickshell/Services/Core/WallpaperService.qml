pragma Singleton
import QtQuick
import Quickshell
import qs.Services.Utils
import qs.Services.WM

Singleton {
  id: wallpaperService

  property var animationCentersByName: ({})
  readonly property string defaultMode: "fill"         // fill | fit | center | stretch | tile
  readonly property string defaultWallpaper: "/mnt/Work/1Wallpapers/Main/samurai.jpg"
  property var filesByName: ({})
  // { [name]: { wallpaper: string, mode: string, dir?: string, random?: bool, interval?: int } }
  property var prefsByName: ({})
  readonly property bool ready: !!(MonitorService.ready && MonitorService.monitors.count > 0)
  property var timersByName: ({})
  readonly property var wallpapersArray: Array.from({
    length: MonitorService.ready ? MonitorService.monitors.count : 0
  }, (unused, i) => {
    const monitor = MonitorService.monitors.get(i);
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

  signal wallpaperChanged(string name, string path, real centerRelX, real centerRelY)

  function _savePersist() {
    const out = {};
    const names = Object.keys(prefsByName || {});
    for (let i = 0; i < names.length; i++) {
      const n = names[i];
      const p = prefsByName[n] || {};
      out[n] = {
        wallpaper: p.wallpaper || defaultWallpaper,
        mode: p.mode || defaultMode
      };
    }
    try {
      persist.savedWallpapersJson = JSON.stringify(out);
    } catch (e) {}
  }

  // --- random rotation ---
  function applyRandomState(name) {
    const prefs = ensurePrefs(name);
    const timer = ensureTimer(name);
    timer.interval = Math.max(1, (prefs.interval || 300)) * 1000;
    timer.running = !!prefs.random;
    Logger.log("WallpaperService", `Random ${timer.running ? 'enabled' : 'disabled'} for ${name}; interval=${timer.interval}ms`);
  }

  function randomCenterForMonitor(name) {
    const margin = 0.07; // 7% inset to avoid edges
    const rx = margin + Math.random() * (1 - 2 * margin);
    const ry = margin + Math.random() * (1 - 2 * margin);
    return {
      x: rx,
      y: ry
    };
  }

  function rotateRandom(name) {
    const filesForMonitor = filesByName[name] || [];
    if (!filesForMonitor.length)
      return;
    const chosenFile = filesForMonitor[Math.floor(Math.random() * filesForMonitor.length)];
    Logger.log("WallpaperService", `Rotate random: name=${name}, chosen=${chosenFile}`);
    setWallpaper(name, chosenFile);
  }

  function changeMonitorSettings(name, settings) {
    if (MonitorService && MonitorService.applySettings)
      MonitorService.applySettings(name, settings);
  }

  function setMode(name, width, height, refreshRate) {
    if (MonitorService && MonitorService.setMode)
      MonitorService.setMode(name, width, height, refreshRate);
  }

  function setPosition(name, x, y) {
    if (MonitorService && MonitorService.setPosition)
      MonitorService.setPosition(name, x, y);
  }

  function setScale(name, scale) {
    if (MonitorService && MonitorService.setScale)
      MonitorService.setScale(name, scale);
  }

  function setTransform(name, transform) {
    if (MonitorService && MonitorService.setTransform)
      MonitorService.setTransform(name, transform);
  }

  function setVrr(name, mode) {
    if (MonitorService && MonitorService.setVrr)
      MonitorService.setVrr(name, mode);
  }

  function setModePref(name, mode) {
    const prefs = ensurePrefs(name);
    prefs.mode = mode || defaultMode;
    Logger.log("WallpaperService", `Set mode: name=${name}, mode=${prefs.mode}`);
    _savePersist();
  }

  function setRandomDirectory(name, directory, files) {
    const prefs = ensurePrefs(name);
    prefs.dir = directory || "";
    filesByName[name] = Array.isArray(files) ? files : [];
    Logger.log("WallpaperService", `Set random dir: name=${name}, dir=${prefs.dir}, files=${filesByName[name].length}`);
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

  function setWallpaper(name, path) {
    if (!name)
      return;

    const prefs = ensurePrefs(name);
    prefs.wallpaper = path || defaultWallpaper;
    Logger.log("WallpaperService", `Set wallpaper: name=${name}, path=${prefs.wallpaper}`);

    const center = randomCenterForMonitor(name);
    animationCentersByName[name] = center;
    wallpaperService.wallpaperChanged(name, prefs.wallpaper, center.x, center.y);

    const timer = timersByName[name];
    if (timer && timer.running)
      timer.restart();
    _savePersist();
  }

  function wallpaperFor(name) {
    if (!name)
      return null;

    const monitorIndex = MonitorService ? MonitorService.findMonitorIndexByName(name) : -1;
    if (monitorIndex < 0)
      return null;

    const monitor = MonitorService.monitors.get(monitorIndex);
    const prefs = prefsByName[name] || {};
    const center = animationCentersByName[name] || {
      x: 0.5,
      y: 0.5
    };

    return {
      name,
      width: monitor.width,
      height: monitor.height,
      scale: monitor.scale,
      fps: monitor.fps,
      bitDepth: monitor.bitDepth,
      orientation: monitor.orientation,
      wallpaper: prefs.wallpaper || defaultWallpaper,
      mode: prefs.mode || defaultMode,
      animCenterX: center.x,
      animCenterY: center.y
    };
  }

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
    if (animationCentersByName.hasOwnProperty(name))
      delete animationCentersByName[name];
  }

  function syncWithMonitors() {
    if (!MonitorService || !MonitorService.ready) {
      Logger.log("WallpaperService", "sync: monitorService not ready; skipping");
      return;
    }
    Logger.log("WallpaperService", "sync: begin");

    // Ensure prefs/timers for all current monitors
    for (let i = 0; i < MonitorService.monitors.count; i++) {
      const m = MonitorService.monitors.get(i);
      ensurePrefs(m.name);
      ensureTimer(m.name);
    }

    const existing = Object.keys(prefsByName);
    for (let i = 0; i < existing.length; i++) {
      const name = existing[i];
      const idx = MonitorService.findMonitorIndexByName(name);
      if (idx < 0) {
        destroyTimer(name);
        Logger.log("WallpaperService", `Monitor '${name}' not present; preserving prefs and stopping timer`);
      }
    }

    for (let i = 0; i < MonitorService.monitors.count; i++) {
      const m = MonitorService.monitors.get(i);
      applyRandomState(m.name);
    }

    _savePersist();
    Logger.log("WallpaperService", `sync: done; monitors=${MonitorService.monitors.count}, prefs=${Object.keys(prefsByName).length}`);
  }

  Component.onCompleted: {
    if (MonitorService.ready) {
      Logger.log("WallpaperService", "Init: MonitorService ready; syncing");
      syncWithMonitors();
    } else {
      Logger.log("WallpaperService", "Init: MonitorService not ready yet");
    }
  }

  PersistentProperties {
    id: persist
    property string savedWallpapersJson: "{}"

    function hydrate() {
      try {
        const obj = JSON.parse(persist.savedWallpapersJson || "{}");
        for (const name in obj) {
          if (!obj.hasOwnProperty(name))
            continue;
          const saved = obj[name] || {};
          const prefs = wallpaperService.ensurePrefs(name);
          if (typeof saved.wallpaper === "string" && saved.wallpaper)
            prefs.wallpaper = saved.wallpaper;
          if (typeof saved.mode === "string" && saved.mode)
            prefs.mode = saved.mode;
        }
        Logger.log("WallpaperService", `Hydrated ${Object.keys(obj).length} persisted wallpaper entries`);
      } catch (e) {
        Logger.warn("WallpaperService", "Failed to parse persisted wallpapers; resetting store");
        persist.savedWallpapersJson = "{}";
      }

      if (MonitorService && MonitorService.ready)
        wallpaperService.syncWithMonitors();
    }

    reloadableId: "WallpaperService"
    onLoaded: hydrate()
    onReloaded: hydrate()
  }

  Connections {
    target: MonitorService
    function onMonitorsUpdated() {
      if (MonitorService.ready) {
        Logger.log("WallpaperService", "Monitors changed; syncing");
        wallpaperService.syncWithMonitors();
      }
    }
    function onReadyChanged() {
      if (MonitorService.ready) {
        Logger.log("WallpaperService", "MonitorService ready");
        wallpaperService.syncWithMonitors();
      } else {
        Logger.log("WallpaperService", "MonitorService not ready");
      }
    }
  }
}
