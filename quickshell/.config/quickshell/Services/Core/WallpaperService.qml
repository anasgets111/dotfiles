pragma Singleton
import QtQuick
import Quickshell
import qs.Services.Utils
import qs.Config
import qs.Services.WM

Singleton {
  id: wallpaperService

  // Defaults
  readonly property string defaultMode: "fill"          // fill | fit | center | stretch | tile
  readonly property string defaultWallpaper: Settings.defaultWallpaper

  // State
  property bool hydrated: false
  property var prefsByName: ({})                        // { [name]: { wallpaper: string, mode: string } }
  property var animationCentersByName: ({})            // { [name]: { x: real, y: real } }

  // Live flags
  readonly property bool ready: !!(MonitorService.ready && MonitorService.monitors.count > 0)

  // Derived model for UI
  readonly property var monitors: Array.from({
    length: (hydrated && MonitorService.ready) ? MonitorService.monitors.count : 0
  }, (unused, i) => {
    const m = MonitorService.monitors.get(i);
    const p = prefsByName[m.name] || {};
    const c = animationCentersByName[m.name] || {
      x: 0.5,
      y: 0.5
    };
    return {
      name: m.name,
      width: m.width,
      height: m.height,
      scale: m.scale,
      fps: m.fps,
      bitDepth: m.bitDepth,
      orientation: m.orientation,
      wallpaper: p.wallpaper || defaultWallpaper,
      mode: p.mode || defaultMode,
      animCenterX: c.x,
      animCenterY: c.y
    };
  })

  signal wallpaperChanged(string name, string path, real centerRelX, real centerRelY)
  signal modeChanged(string name, string mode)

  // Internal helpers
  function _randomCenter() {
    const margin = 0.07;
    return {
      x: margin + Math.random() * (1 - 2 * margin),
      y: margin + Math.random() * (1 - 2 * margin)
    };
  }

  function _ensurePrefs(name) {
    if (!prefsByName.hasOwnProperty(name)) {
      prefsByName[name] = {
        wallpaper: defaultWallpaper,
        mode: defaultMode
      };
    }
    return prefsByName[name];
  }

  function _persistMonitors() {
    if (!hydrated || !(Settings && Settings.data))
      return;
    const out = {};
    if (MonitorService && MonitorService.ready) {
      for (let i = 0; i < MonitorService.monitors.count; i++) {
        const n = MonitorService.monitors.get(i).name;
        const p = prefsByName[n] || {};
        out[n] = {
          wallpaper: p.wallpaper || defaultWallpaper,
          mode: p.mode || defaultMode
        };
      }
    }
    try {
      Logger.log("WallpaperService", "Saving monitors JSON: " + JSON.stringify(out));
    } catch (e) {
      Logger.log("WallpaperService", "Saving monitors JSON: [stringify failed]");
    }
    try {
      Settings.data["monitors"] = out;
    } catch (e) {}
  }

  function _announceAll() {
    if (!hydrated || !MonitorService || !MonitorService.ready)
      return;
    for (let i = 0; i < MonitorService.monitors.count; i++) {
      const m = MonitorService.monitors.get(i);
      if (!animationCentersByName.hasOwnProperty(m.name))
        animationCentersByName[m.name] = _randomCenter();
      const p = prefsByName[m.name] || {};
      const c = animationCentersByName[m.name];
      wallpaperService.wallpaperChanged(m.name, p.wallpaper || defaultWallpaper, c.x, c.y);
    }
  }

  // Public API
  function setModePref(name, mode) {
    if (!name)
      return;
    const p = _ensurePrefs(name);
    p.mode = (typeof mode === "string" && !!mode) ? mode : defaultMode;
    Logger.log("WallpaperService", `mode set: ${name} -> ${p.mode}`);
    wallpaperService.modeChanged(name, p.mode);
    _persistMonitors();
  }

  function setWallpaper(name, path) {
    if (!name)
      return;
    const p = _ensurePrefs(name);
    p.wallpaper = (typeof path === "string" && !!path) ? path : defaultWallpaper;
    const c = _randomCenter();
    animationCentersByName[name] = c;
    Logger.log("WallpaperService", `wallpaper set: ${name} -> ${p.wallpaper}`);
    wallpaperService.wallpaperChanged(name, p.wallpaper, c.x, c.y);
    _persistMonitors();
  }

  function wallpaperFor(name) {
    if (!name || !hydrated || !MonitorService || !MonitorService.ready)
      return null;
    const idx = MonitorService.findMonitorIndexByName(name);
    if (idx < 0)
      return null;
    const m = MonitorService.monitors.get(idx);
    const p = prefsByName[name] || {};
    const c = animationCentersByName[name] || {
      x: 0.5,
      y: 0.5
    };
    return {
      name,
      width: m.width,
      height: m.height,
      scale: m.scale,
      fps: m.fps,
      bitDepth: m.bitDepth,
      orientation: m.orientation,
      wallpaper: p.wallpaper || defaultWallpaper,
      mode: p.mode || defaultMode,
      animCenterX: c.x,
      animCenterY: c.y
    };
  }

  function hydrateFromSettings() {
    if (!(Settings && Settings.data))
      return;
    let map = {};
    try {
      map = Settings.data["monitors"] || {};
    } catch (e) {}
    try {
      Logger.log("WallpaperService", "Loaded monitors JSON: " + JSON.stringify(map));
    } catch (e) {
      Logger.log("WallpaperService", "Loaded monitors JSON: [stringify failed]");
    }
    // Copy persisted prefs, ignore junk keys
    for (const k in map) {
      if (!map.hasOwnProperty(k))
        continue;
      const v = map[k] || {};
      prefsByName[k] = {
        wallpaper: (typeof v.wallpaper === "string" && v.wallpaper) ? v.wallpaper : defaultWallpaper,
        mode: (typeof v.mode === "string" && v.mode) ? v.mode : defaultMode
      };
    }
    // Seed current monitors if empty
    if (Object.keys(prefsByName).length === 0 && MonitorService && MonitorService.ready) {
      for (let i = 0; i < MonitorService.monitors.count; i++) {
        _ensurePrefs(MonitorService.monitors.get(i).name);
      }
    }
    hydrated = true;
    _announceAll();
    _persistMonitors();
    Logger.log("WallpaperService", `hydrated monitors prefs: ${Object.keys(prefsByName).length}`);
  }

  // Lifecycle wiring
  Connections {
    target: Settings
    function onIsLoadedChanged() {
      if (Settings.isLoaded && !wallpaperService.hydrated)
        wallpaperService.hydrateFromSettings();
    }
  }

  Component.onCompleted: {
    if (Settings && Settings.isLoaded && !hydrated)
      hydrateFromSettings();
  }

  Connections {
    target: MonitorService
    function onMonitorsUpdated() {
      if (MonitorService.ready)
        wallpaperService._announceAll();
    }
    function onReadyChanged() {
      if (MonitorService.ready)
        wallpaperService._announceAll();
    }
  }
}
