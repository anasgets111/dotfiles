pragma Singleton
import QtQuick
import Quickshell
import qs.Config
import qs.Services.WM

Singleton {
  id: self

  readonly property string defaultMode: "fill"
  readonly property string defaultWallpaper: Settings.defaultWallpaper
  readonly property string defaultTransition: "disc"

  property bool hydrated: false
  property var monitorPrefs: ({})        // name -> { wallpaper, mode }
  property var lastAnnounced: ({})       // name -> { wallpaper, mode }
  // Global transition setting for wallpaper changes
  property string wallpaperTransition: defaultTransition
  property string _persistKey: ""

  Timer {
    id: announceDebounce
    interval: 50
    repeat: false
    onTriggered: self.announceAll()
  }
  Timer {
    id: persistDebounce
    interval: 80
    repeat: false
    onTriggered: self.persistMonitors()
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
      out.push({
        name: m.name,
        width: m.width,
        height: m.height,
        scale: m.scale,
        fps: m.fps,
        bitDepth: m.bitDepth,
        orientation: m.orientation,
        wallpaper: prefs.wallpaper,
        mode: prefs.mode
      });
    }
    return out;
  }

  signal wallpaperChanged(string monitorName, string wallpaperPath)
  signal modeChanged(string monitorName, string mode)
  signal transitionChanged(string transition)

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
  function validTransition(t) {
    switch ((t || "").toString().toLowerCase()) {
    case "fade":
    case "wipe":
    case "disc":
    case "stripes":
    case "portal":
      return t.toLowerCase();
    default:
      return defaultTransition;
    }
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

      const prev = lastAnnounced[name];
      if (prev && prev.wallpaper === prefs.wallpaper && prev.mode === prefs.mode)
        continue;

      lastAnnounced[name] = {
        wallpaper: prefs.wallpaper,
        mode: prefs.mode
      };
      wallpaperChanged(name, prefs.wallpaper);
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
    const t = validTransition(wallpaperTransition);
    const key = JSON.stringify([out, t]);
    if (key === _persistKey)
      return;
    _persistKey = key;
    Settings.data.wallpapers = out;
    Settings.data.wallpaperTransition = t;
  }

  function setModePref(name, mode) {
    if (!name)
      return;
    const p = ensurePrefs(name);
    const v = validMode(mode);
    if (p.mode === v)
      return;
    p.mode = v;
    modeChanged(name, p.mode);
    persistDebounce.restart();
  }

  function setWallpaper(name, path) {
    if (!name)
      return;
    const p = ensurePrefs(name);
    const v = (typeof path === "string" && path) ? path : defaultWallpaper;
    if (p.wallpaper === v)
      return;
    p.wallpaper = v;
    wallpaperChanged(name, p.wallpaper);
    persistDebounce.restart();
  }

  function setWallpaperTransition(transition) {
    const v = validTransition(transition);
    if (wallpaperTransition === v)
      return;
    wallpaperTransition = v;
    transitionChanged(wallpaperTransition);
    if (Settings?.data)
      Settings.data.wallpaperTransition = wallpaperTransition;
  }

  function wallpaperFor(name) {
    if (!name || !ready)
      return null;
    const idx = MonitorService.findMonitorIndexByName(name);
    if (idx < 0)
      return null;
    const m = MonitorService.monitors.get(idx);
    const p = ensurePrefs(name);
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
      transition: wallpaperTransition
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
    if (typeof Settings.data.wallpaperTransition === "string")
      wallpaperTransition = validTransition(Settings.data.wallpaperTransition);
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
