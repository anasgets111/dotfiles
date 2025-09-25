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
  property var monitorPrefs: ({})
  property var monitorCenters: ({})
  property var lastAnnounced: ({})

  Timer {
    id: announceDebounce
    interval: 50
    repeat: false
    onTriggered: self._announceAll()
  }

  readonly property bool ready: hydrated && MonitorService?.ready && MonitorService.monitors?.count > 0

  function _validModeOrDefault(mode) {
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
  function _randomCenter() {
    const m = 0.07;
    return {
      x: m + Math.random() * (1 - 2 * m),
      y: m + Math.random() * (1 - 2 * m)
    };
  }

  function _ensurePrefs(name) {
    let p = monitorPrefs[name];
    if (!p)
      p = monitorPrefs[name] = {
        wallpaper: defaultWallpaper,
        mode: defaultMode
      };
    return p;
  }
  function _ensureCenter(name) {
    let c = monitorCenters[name];
    if (!c)
      c = monitorCenters[name] = {
        x: 0.5,
        y: 0.5
      };
    return c;
  }
  function _seedCurrentMonitors() {
    if (!MonitorService?.ready)
      return;
    const n = MonitorService.monitors.count;
    for (let i = 0; i < n; i++)
      _ensurePrefs(MonitorService.monitors.get(i).name);
  }

  readonly property var monitors: {
    if (!ready)
      return [];
    const out = [];
    const n = MonitorService.monitors.count;
    for (let i = 0; i < n; i++) {
      const m = MonitorService.monitors.get(i);
      const prefs = _ensurePrefs(m.name);
      const center = _ensureCenter(m.name);
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

  function _announceAll() {
    if (!hydrated || !MonitorService?.ready || !MonitorService.monitors?.count)
      return;
    const n = MonitorService.monitors.count;
    for (let i = 0; i < n; i++) {
      const name = MonitorService.monitors.get(i).name;
      const prefs = _ensurePrefs(name);
      let center = monitorCenters[name];
      if (!center)
        center = monitorCenters[name] = _randomCenter();

      const prev = lastAnnounced[name];
      if (prev && prev.wallpaper === prefs.wallpaper && prev.mode === prefs.mode && prev.centerX === center.x && prev.centerY === center.y)
        continue;

      lastAnnounced[name] = {
        wallpaper: prefs.wallpaper,
        mode: prefs.mode,
        centerX: center.x,
        centerY: center.y
      };
      self.wallpaperChanged(name, prefs.wallpaper, center.x, center.y);
    }
  }

  function _persistMonitors() {
    if (!hydrated || !Settings?.data || !MonitorService?.ready || !MonitorService.monitors?.count)
      return;
    const out = {};
    const n = MonitorService.monitors.count;
    for (let i = 0; i < n; i++) {
      const name = MonitorService.monitors.get(i).name;
      const p = monitorPrefs[name] || {};
      out[name] = {
        wallpaper: (typeof p.wallpaper === "string" && p.wallpaper) ? p.wallpaper : defaultWallpaper,
        mode: _validModeOrDefault(p.mode)
      };
    }
    Settings.data.wallpapers = out;
  }

  function setModePref(name, mode) {
    if (!name)
      return;
    const p = _ensurePrefs(name);
    p.mode = _validModeOrDefault(mode);
    self.modeChanged(name, p.mode);
    _persistMonitors();
  }

  function setWallpaper(name, path) {
    if (!name)
      return;
    const p = _ensurePrefs(name);
    p.wallpaper = (typeof path === "string" && path) ? path : defaultWallpaper;
    const c = _randomCenter();
    monitorCenters[name] = c;
    self.wallpaperChanged(name, p.wallpaper, c.x, c.y);
    _persistMonitors();
  }

  function wallpaperFor(name) {
    if (!name || !ready)
      return null;
    const idx = MonitorService.findMonitorIndexByName(name);
    if (idx < 0)
      return null;
    const m = MonitorService.monitors.get(idx);
    const p = _ensurePrefs(name);
    const c = _ensureCenter(name);
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
        mode: _validModeOrDefault(sp.mode)
      };
    }
    if (Object.keys(monitorPrefs).length === 0 && MonitorService.ready)
      _seedCurrentMonitors();
    hydrated = true;
    if (MonitorService.ready)
      self._announceAll();
    _persistMonitors();
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
        self._seedCurrentMonitors();
        announceDebounce.restart();
      }
    }
    function onMonitorsUpdated() {
      if (MonitorService.ready && self.hydrated) {
        self._seedCurrentMonitors();
        announceDebounce.restart();
        self._persistMonitors();
      }
    }
  }
}
