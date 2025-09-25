pragma Singleton
import QtQuick
import Quickshell
import qs.Config
import qs.Services.WM

Singleton {
  id: self

  readonly property string defaultMode: "fill"
  readonly property string defaultWallpaper: Settings.defaultWallpaper

  property bool hydrated: false
  property var monitorPrefs: ({})        // name -> { wallpaper, mode }
  property var monitorCenters: ({})      // name -> { x, y }
  property var lastAnnounced: ({})       // name -> { wallpaper, mode, centerX, centerY }
  Timer {
    id: announceDebounce
    interval: 50
    repeat: false
    onTriggered: self.announceAll()
  }

  readonly property bool ready: hydrated && MonitorService?.ready && MonitorService.monitors?.count > 0

  readonly property var monitors: {
    if (!ready)
      return [];
    const out = [];
    const n = MonitorService.monitors.count;
    for (let i = 0; i < n; i++) {
      const m = MonitorService.monitors.get(i);
      const prefs = ensurePrefs(m.name);
      const center = ensureCenter(m.name);
      out.push({
        name: m.name,
        width: m.width,
        height: m.height,
        scale: m.scale,
        fps: m.fps,
        bitDepth: m.bitDepth,
        orientation: m.orientation,
        wallpaper: prefs.wallpaper,
        mode: prefs.mode,
        animCenterX: center.x,
        animCenterY: center.y
      });
    }
    return out;
  }

  signal wallpaperChanged(string monitorName, string wallpaperPath, real centerRelX, real centerRelY)
  signal modeChanged(string monitorName, string mode)

  function validMode(mode) {
    switch (mode) {
    case "fill":
    case "fit":
    case "center":
    case "stretch":
    case "tile":
      return mode;
    default:
      return defaultMode;
    }
  }
  function randomCenter() {
    const margin = 0.07;
    return {
      x: margin + Math.random() * (1 - 2 * margin),
      y: margin + Math.random() * (1 - 2 * margin)
    };
  }
  function ensurePrefs(name) {
    let p = monitorPrefs[name];
    if (!p)
      p = monitorPrefs[name] = {
        wallpaper: defaultWallpaper,
        mode: defaultMode
      };
    return p;
  }
  function ensureCenter(name) {
    let c = monitorCenters[name];
    if (!c)
      c = monitorCenters[name] = {
        x: 0.5,
        y: 0.5
      };
    return c;
  }
  function seedCurrentMonitors() {
    if (!MonitorService?.ready)
      return;
    const n = MonitorService.monitors.count;
    for (let i = 0; i < n; i++)
      ensurePrefs(MonitorService.monitors.get(i).name);
  }

  function announceAll() {
    if (!hydrated || !MonitorService?.ready || !MonitorService.monitors?.count)
      return;
    const n = MonitorService.monitors.count;
    for (let i = 0; i < n; i++) {
      const name = MonitorService.monitors.get(i).name;
      const prefs = ensurePrefs(name);
      let center = monitorCenters[name];
      if (!center)
        center = monitorCenters[name] = randomCenter();

      const prev = lastAnnounced[name];
      if (prev && prev.wallpaper === prefs.wallpaper && prev.mode === prefs.mode && prev.centerX === center.x && prev.centerY === center.y)
        continue;

      lastAnnounced[name] = {
        wallpaper: prefs.wallpaper,
        mode: prefs.mode,
        centerX: center.x,
        centerY: center.y
      };
      wallpaperChanged(name, prefs.wallpaper, center.x, center.y);
    }
  }

  function persistMonitors() {
    if (!hydrated || !Settings?.data || !MonitorService?.ready || !MonitorService.monitors?.count)
      return;
    const out = {};
    const n = MonitorService.monitors.count;
    for (let i = 0; i < n; i++) {
      const name = MonitorService.monitors.get(i).name;
      const p = monitorPrefs[name] || {};
      out[name] = {
        wallpaper: (typeof p.wallpaper === "string" && p.wallpaper) ? p.wallpaper : defaultWallpaper,
        mode: validMode(p.mode)
      };
    }
    Settings.data.wallpapers = out;
  }

  function setModePref(name, mode) {
    if (!name)
      return;
    const p = ensurePrefs(name);
    p.mode = validMode(mode);
    modeChanged(name, p.mode);
    persistMonitors();
  }

  function setWallpaper(name, path) {
    if (!name)
      return;
    const p = ensurePrefs(name);
    p.wallpaper = (typeof path === "string" && path) ? path : defaultWallpaper;
    const c = randomCenter();
    monitorCenters[name] = c;
    wallpaperChanged(name, p.wallpaper, c.x, c.y);
    persistMonitors();
  }

  function wallpaperFor(name) {
    if (!name || !ready)
      return null;
    const idx = MonitorService.findMonitorIndexByName(name);
    if (idx < 0)
      return null;
    const m = MonitorService.monitors.get(idx);
    const p = ensurePrefs(name);
    const c = ensureCenter(name);
    return {
      name: m.name,
      width: m.width,
      height: m.height,
      scale: m.scale,
      fps: m.fps,
      bitDepth: m.bitDepth,
      orientation: m.orientation,
      wallpaper: p.wallpaper,
      mode: p.mode,
      animCenterX: c.x,
      animCenterY: c.y
    };
  }

  function hydrateFromSettings() {
    if (!Settings?.data || hydrated)
      return;
    const saved = Settings.data.wallpapers || {};
    for (const name in saved) {
      const sp = saved[name] || {};
      monitorPrefs[name] = {
        wallpaper: (typeof sp.wallpaper === "string" && sp.wallpaper) ? sp.wallpaper : defaultWallpaper,
        mode: validMode(sp.mode)
      };
    }
    if (Object.keys(monitorPrefs).length === 0 && MonitorService.ready)
      seedCurrentMonitors();
    hydrated = true;
    if (MonitorService.ready)
      announceAll();
    persistMonitors();
  }

  Component.onCompleted: {
    if (Settings?.isLoaded && !hydrated)
      hydrateFromSettings();
  }

  Connections {
    target: Settings
    function onIsLoadedChanged() {
      if (Settings.isLoaded && !self.hydrated)
        self.hydrateFromSettings();
    }
  }
  Connections {
    target: MonitorService
    function onReadyChanged() {
      if (MonitorService.ready && self.hydrated) {
        self.seedCurrentMonitors();
        announceDebounce.restart();
      }
    }
    function onMonitorsUpdated() {
      if (MonitorService.ready && self.hydrated) {
        self.seedCurrentMonitors();
        announceDebounce.restart();
        self.persistMonitors();
      }
    }
  }
}
