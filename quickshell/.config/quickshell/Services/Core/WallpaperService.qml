pragma Singleton
import QtQuick
import Quickshell
import qs.Services.Utils
import qs.Config
import qs.Services.WM

Singleton {
  id: wallpaperService

  // Defaults
  readonly property string defaultMode: "fill"  // fill | fit | center | stretch | tile
  readonly property string defaultWallpaper: Settings.defaultWallpaper

  // State
  property bool hydrated: false
  property var prefsByName: ({})  // { [monitorName]: { wallpaper: string, mode: string } }
  property var animationCentersByName: ({})  // { [monitorName]: { x: real, y: real } }
  // + add a cache for last emission
  property var lastAnnouncedByName: ({})

  // + tiny coalescing timer
  Timer {
    id: announceDebounce
    interval: 50
    repeat: false
    onTriggered: wallpaperService._announceAll()
  }

  // Live flags
  readonly property bool ready: hydrated && MonitorService?.ready && MonitorService.monitors?.count > 0

  // Derived model for UI (reactive; rebuilds on state/monitor changes)
  readonly property var monitors: {
    if (!ready)
      return [];
    const monitorsArray = [];
    const defaultPreferences = {
      wallpaper: defaultWallpaper,
      mode: defaultMode
    };
    const defaultAnimationCenter = {
      x: 0.5,
      y: 0.5
    };
    for (let monitorIndex = 0; monitorIndex < MonitorService.monitors.count; monitorIndex++) {
      const monitor = MonitorService.monitors.get(monitorIndex);
      let preferences = prefsByName[monitor.name];
      if (!preferences) {
        preferences = defaultPreferences;
        prefsByName[monitor.name] = preferences;  // Seed proactively.
      }
      let animationCenter = animationCentersByName[monitor.name];
      if (!animationCenter) {
        animationCenter = defaultAnimationCenter;
        animationCentersByName[monitor.name] = animationCenter;  // Seed if missing.
      }
      monitorsArray.push({
        name: monitor.name,
        width: monitor.width,
        height: monitor.height,
        scale: monitor.scale,
        fps: monitor.fps,
        bitDepth: monitor.bitDepth,
        orientation: monitor.orientation,
        wallpaper: preferences.wallpaper,
        mode: preferences.mode,
        animCenterX: animationCenter.x,
        animCenterY: animationCenter.y
      });
    }
    return monitorsArray;
  }

  signal wallpaperChanged(string monitorName, string wallpaperPath, real centerRelX, real centerRelY)
  signal modeChanged(string monitorName, string mode)

  // Internal helpers
  function _randomCenter() {
    const margin = 0.07;
    return {
      x: margin + Math.random() * (1 - 2 * margin),
      y: margin + Math.random() * (1 - 2 * margin)
    };
  }

  function _ensurePrefs(monitorName) {
    if (!prefsByName[monitorName]) {
      prefsByName[monitorName] = {
        wallpaper: defaultWallpaper,
        mode: defaultMode
      };
    }
    return prefsByName[monitorName];
  }

  function _announceAll() {
    if (!hydrated || !MonitorService?.ready || !MonitorService.monitors?.count)
      return;
    for (let i = 0; i < MonitorService.monitors.count; i++) {
      const monitor = MonitorService.monitors.get(i);
      _ensurePrefs(monitor.name);

      let animationCenter = animationCentersByName[monitor.name];
      if (!animationCenter) {
        animationCenter = _randomCenter();
        animationCentersByName[monitor.name] = animationCenter;
      }

      const preferences = prefsByName[monitor.name];
      const prev = lastAnnouncedByName[monitor.name];
      if (prev && prev.wallpaper === preferences.wallpaper && prev.mode === preferences.mode && prev.centerX === animationCenter.x && prev.centerY === animationCenter.y) {
        continue; // unchanged → skip
      }

      lastAnnouncedByName[monitor.name] = {
        wallpaper: preferences.wallpaper,
        mode: preferences.mode,
        centerX: animationCenter.x,
        centerY: animationCenter.y
      };
      wallpaperService.wallpaperChanged(monitor.name, preferences.wallpaper, animationCenter.x, animationCenter.y);
    }
  }

  function _persistMonitors() {
    if (!hydrated || !Settings?.data || !MonitorService?.ready || !MonitorService.monitors?.count)
      return;
    const wallpaperPreferences = {};
    for (let monitorIndex = 0; monitorIndex < MonitorService.monitors.count; monitorIndex++) {
      const monitorName = MonitorService.monitors.get(monitorIndex).name;
      const preferences = prefsByName[monitorName] || {};
      wallpaperPreferences[monitorName] = {
        wallpaper: preferences.wallpaper || defaultWallpaper,
        mode: preferences.mode || defaultMode
      };
    }
    try {
      Settings.data.wallpapers = wallpaperPreferences;
    } catch (error) {
      Logger.log("WallpaperService", "Persist failed: " + error.message);
    }
    Logger.log("WallpaperService", `Saved wallpapers: ${Object.keys(wallpaperPreferences).length}`);
  }

  // Public API
  function setModePref(monitorName, mode) {
    if (!monitorName)
      return;
    const preferences = _ensurePrefs(monitorName);
    preferences.mode = (typeof mode === "string" && mode) ? mode : defaultMode;
    wallpaperService.modeChanged(monitorName, preferences.mode);
    _persistMonitors();
    Logger.log("WallpaperService", `Mode set for ${monitorName}: ${preferences.mode}`);
  }

  function setWallpaper(monitorName, wallpaperPath) {
    if (!monitorName)
      return;
    const preferences = _ensurePrefs(monitorName);
    preferences.wallpaper = (typeof wallpaperPath === "string" && wallpaperPath) ? wallpaperPath : defaultWallpaper;
    const animationCenter = _randomCenter();
    animationCentersByName[monitorName] = animationCenter;
    wallpaperService.wallpaperChanged(monitorName, preferences.wallpaper, animationCenter.x, animationCenter.y);
    _persistMonitors();
    Logger.log("WallpaperService", `Wallpaper set for ${monitorName}: ${preferences.wallpaper}`);
  }

  function wallpaperFor(monitorName) {
    if (!monitorName || !ready)
      return null;
    const monitorIndex = MonitorService.findMonitorIndexByName(monitorName);
    if (monitorIndex < 0)
      return null;
    const monitor = MonitorService.monitors.get(monitorIndex);
    _ensurePrefs(monitorName);  // Ensure seeded for this query.
    let animationCenter = animationCentersByName[monitorName];
    if (!animationCenter) {
      animationCenter = {
        x: 0.5,
        y: 0.5
      };
      animationCentersByName[monitorName] = animationCenter;
    }
    const preferences = prefsByName[monitorName];
    return {
      name: monitor.name,
      width: monitor.width,
      height: monitor.height,
      scale: monitor.scale,
      fps: monitor.fps,
      bitDepth: monitor.bitDepth,
      orientation: monitor.orientation,
      wallpaper: preferences.wallpaper,
      mode: preferences.mode,
      animCenterX: animationCenter.x,
      animCenterY: animationCenter.y
    };
  }

  function hydrateFromSettings() {
    if (!Settings?.data || hydrated)
      return;
    const savedWallpapers = Settings.data.wallpapers || {};
    for (const savedMonitorName in savedWallpapers) {
      const savedPreferences = savedWallpapers[savedMonitorName] || {};
      prefsByName[savedMonitorName] = {
        wallpaper: (typeof savedPreferences.wallpaper === "string" && savedPreferences.wallpaper) ? savedPreferences.wallpaper : defaultWallpaper,
        mode: (typeof savedPreferences.mode === "string" && savedPreferences.mode) ? savedPreferences.mode : defaultMode
      };
    }
    // Seed current monitors if persisted was empty (initial setup), but defer if monitors not ready.
    if (Object.keys(prefsByName).length === 0) {
      if (MonitorService.ready) {
        for (let monitorIndex = 0; monitorIndex < MonitorService.monitors.count; monitorIndex++) {
          _ensurePrefs(MonitorService.monitors.get(monitorIndex).name);
        }
      }
      // Else: Defer to onReadyChanged/onMonitorsUpdated.
    }
    hydrated = true;
    if (MonitorService.ready)
      wallpaperService._announceAll();
    _persistMonitors();  // Save loaded/seeded state.
    Logger.log("WallpaperService", `Hydrated wallpapers for ${Object.keys(prefsByName).length} monitors`);
  }

  // Lifecycle wiring (guards ensure precise sequencing on load/reopen)
  Component.onCompleted: {
    if (Settings && Settings.isLoaded && !hydrated)
      hydrateFromSettings();
  }

  Connections {
    target: Settings
    function onIsLoadedChanged() {
      if (Settings.isLoaded && !wallpaperService.hydrated)
        wallpaperService.hydrateFromSettings();
    }
  }

  Connections {
    target: MonitorService
    function onReadyChanged() {
      if (MonitorService.ready && wallpaperService.hydrated) {
        // Seed new monitors if not already (post-hydrate race).
        for (let i = 0; i < MonitorService.monitors.count; i++)
          wallpaperService._ensurePrefs(MonitorService.monitors.get(i).name);
        announceDebounce.restart();
      }
    }
    function onMonitorsUpdated() {
      if (MonitorService.ready && wallpaperService.hydrated) {
        // Seed any new/updated monitors.
        for (let i = 0; i < MonitorService.monitors.count; i++)
          wallpaperService._ensurePrefs(MonitorService.monitors.get(i).name);
        announceDebounce.restart();
        wallpaperService._persistMonitors();  // Persist after update (includes new seeds).
      }
    }
  }
}
