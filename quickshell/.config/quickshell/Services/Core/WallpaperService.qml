pragma Singleton
import QtQuick
import Quickshell
import qs.Services.Utils
import qs.Services.WM

Singleton {
  id: wallpaperService

  // Normalized animation centers per monitor (0..1 in each dimension)
  // { [name]: { x: real, y: real } }
  property var animationCentersByName: ({})
  property string defaultMode: "fill" // fill | fit | center, etc.
  property string defaultWallpaper: "/mnt/Work/1Wallpapers/Main/samurai.jpg"
  property var filesByName: ({})
  // { [name]: { wallpaper: string, mode: string, dir?: string, random?: bool, interval?: int } }
  property var prefsByName: ({})
  readonly property bool ready: !!(MonitorService.ready && MonitorService.monitors.count > 0)
  property var timersByName: ({})
  readonly property var wallpapersArray: Array.from({
    "length": MonitorService.ready ? MonitorService.monitors.count : 0
  }, (unusedValue, monitorIndex) => {
    const monitor = MonitorService.monitors.get(monitorIndex);
    const prefs = prefsByName[monitor.name] || {};
    return {
      "name": monitor.name,
      "width": monitor.width,
      "height": monitor.height,
      "scale": monitor.scale,
      "fps": monitor.fps,
      "bitDepth": monitor.bitDepth,
      "orientation": monitor.orientation,
      "wallpaper": prefs.wallpaper || defaultWallpaper,
      "mode": prefs.mode || defaultMode
    };
  })

  // Emitted whenever a wallpaper changes for a monitor.
  // centerRelX/centerRelY are normalized [0..1] coordinates within that monitor.
  signal wallpaperChanged(string name, string path, real centerRelX, real centerRelY)

  // --- Persistence (avoids deprecated Qt.labs.settings) ---
  function _hydratePersist() {
    try {
      const obj = JSON.parse(persist.savedWallpapersJson || "{}");
      // Apply saved wallpapers per monitor name
      for (const key in obj) {
        if (!obj.hasOwnProperty(key))
          continue;
        const saved = obj[key] || {};
        const prefs = ensurePrefs(key);
        if (saved.wallpaper && typeof saved.wallpaper === "string")
          prefs.wallpaper = saved.wallpaper;
        if (saved.mode && typeof saved.mode === "string")
          prefs.mode = saved.mode;
      }
      Logger.log("WallpaperService", `Hydrated ${Object.keys(obj).length} persisted wallpaper entries`);
    } catch (e) {
      Logger.warn("WallpaperService", "Failed to parse persisted wallpapers; resetting store");
      persist.savedWallpapersJson = "{}";
    }
  }
  function _savePersist() {
    // Build a minimal map of { [name]: { wallpaper, mode } }
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
    } catch (e)
    // ignore
    {}
  }
  function applyRandomState(name) {
    const prefs = ensurePrefs(name);
    const timer = ensureTimer(name);
    timer.interval = Math.max(1, (prefs.interval || 300)) * 1000;
    timer.running = !!prefs.random;
    Logger.log("WallpaperService", `Random ${timer.running ? 'enabled' : 'disabled'} for ${name}; interval=${timer.interval}ms`);
  }
  function changeMonitorSettings(settings) {
    if (MonitorService && MonitorService.applySettings)
      MonitorService.applySettings(settings);
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
  function ensureAnimCenter(name) {
    if (!animationCentersByName.hasOwnProperty(name))
      animationCentersByName[name] = {
        "x": 0.5,
        "y": 0.5
      };
    return animationCentersByName[name];
  }
  function ensurePrefs(name) {
    if (!prefsByName.hasOwnProperty(name))
      prefsByName[name] = {
        "wallpaper": defaultWallpaper,
        "mode": defaultMode,
        "random": false,
        "interval": 300
      };

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
  function randomCenterForMonitor(name) {
    // Return normalized coordinates within [margin, 1 - margin] to avoid starting exactly on edges
    const margin = 0.07; // 7% inset
    const rx = margin + Math.random() * (1 - 2 * margin);
    const ry = margin + Math.random() * (1 - 2 * margin);
    return {
      "x": rx,
      "y": ry
    };
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
  // Convenience: set the same wallpaper on all connected monitors.
  // If Quickshell is still initializing, this will be a no-op until MonitorService is ready.
  function setCurrentWallpaper(path /*unused*/, fromSettings) {
    if (!MonitorService || !MonitorService.ready)
      return;
    for (let i = 0; i < MonitorService.monitors.count; i++) {
      const mon = MonitorService.monitors.get(i);
      setWallpaper(mon.name, path);
    }
  }
  function setMode(name, width, height, refreshRate) {
    if (MonitorService && MonitorService.setMode)
      MonitorService.setMode(name, width, height, refreshRate);
  }
  function setModePref(name, mode) {
    const prefs = ensurePrefs(name);
    prefs.mode = mode || defaultMode;
    Logger.log("WallpaperService", `Set mode: name=${name}, mode=${prefs.mode}`);
    _savePersist();
  }
  function setPosition(name, positionX, positionY) {
    if (MonitorService && MonitorService.setPosition)
      MonitorService.setPosition(name, positionX, positionY);
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
  function setWallpaper(nameOrScreen, path) {
    const name = typeof nameOrScreen === "string" ? nameOrScreen : (nameOrScreen && nameOrScreen.name) || null;
    if (!name)
      return;

    const prefs = ensurePrefs(name);
    prefs.wallpaper = path || defaultWallpaper;
    Logger.log("WallpaperService", `Set wallpaper: name=${name}, path=${prefs.wallpaper}`);
    // Pick a fresh random animation center for this monitor
    const center = randomCenterForMonitor(name);
    animationCentersByName[name] = center;
    // Notify listeners with normalized coordinates
    wallpaperService.wallpaperChanged(name, prefs.wallpaper, center.x, center.y);
    const timer = timersByName[name];
    if (timer && timer.running)
      timer.restart();

    // Persist current state
    _savePersist();
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
        destroyTimer(name);
        Logger.log("WallpaperService", `Monitor '${name}' not present; preserving prefs and stopping timer`);
      }
    }
    for (let monitorIndex = 0; monitorIndex < MonitorService.monitors.count; monitorIndex++) {
      const monitor = MonitorService.monitors.get(monitorIndex);
      applyRandomState(monitor.name);
    }
    _savePersist();
    Logger.log("WallpaperService", `sync: done; monitors=${MonitorService.monitors.count}, prefs=${Object.keys(prefsByName).length}`);
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
    const center = animationCentersByName[name] || {
      x: 0.5,
      y: 0.5
    };
    return {
      "name": name,
      "width": monitor.width,
      "height": monitor.height,
      "scale": monitor.scale,
      "fps": monitor.fps,
      "bitDepth": monitor.bitDepth,
      "orientation": monitor.orientation,
      "wallpaper": prefs.wallpaper || defaultWallpaper,
      "mode": prefs.mode || defaultMode,
      "animCenterX": center.x,
      "animCenterY": center.y
    };
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

    // JSON object: { [monitorName]: { wallpaper: string, mode: string } }
    property string savedWallpapersJson: "{}"

    function hydrate() {
      wallpaperService._hydratePersist();
      // After hydration, if monitors are ready, ensure timers exist and states applied
      if (MonitorService && MonitorService.ready)
        wallpaperService.syncWithMonitors();
    }

    reloadableId: "WallpaperService"

    onLoaded: hydrate()
    onReloaded: hydrate()
  }
  Connections {
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

    target: MonitorService
  }
}
