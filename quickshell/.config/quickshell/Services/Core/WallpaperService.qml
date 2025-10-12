pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.Config
import qs.Services.WM

Singleton {
  id: root

  readonly property list<string> availableModes: ["fill", "fit", "center", "stretch", "tile"]
  readonly property list<string> availableTransitions: ["fade", "wipe", "disc", "stripes", "portal"]
  readonly property string defaultMode: "fill"
  readonly property string defaultTransition: "disc"
  readonly property string defaultWallpaper: Settings.defaultWallpaper
  property bool hydrated: false
  property var lastAnnounced: ({})
  property var monitorPrefs: ({})
  readonly property list<var> monitors: {
    if (!ready)
      return [];
    const out = [];
    const count = MonitorService.monitors.count;
    for (let i = 0; i < count; i++) {
      const m = MonitorService.monitors.get(i);
      const prefs = root.ensurePrefs(m.name);
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
  property string persistKey: ""
  readonly property bool ready: hydrated && MonitorService?.ready && (MonitorService.monitors?.count ?? 0) > 0
  property list<var> wallpaperFiles: []
  readonly property bool wallpaperFilesReady: wallpaperFolderModel.status === FolderListModel.Ready
  property string wallpaperFolder: "/mnt/Work/1Wallpapers/Main"
  property string wallpaperTransition: defaultTransition

  signal modeChanged(string monitorName, string mode)
  signal transitionChanged(string transition)
  signal wallpaperChanged(string monitorName, string wallpaperPath)

  function announceAll() {
    if (!ready)
      return;
    const count = MonitorService.monitors.count;
    for (let i = 0; i < count; i++) {
      const name = MonitorService.monitors.get(i).name;
      const prefs = root.ensurePrefs(name);
      const prev = lastAnnounced[name];
      if (prev?.wallpaper === prefs.wallpaper && prev?.mode === prefs.mode)
        continue;
      lastAnnounced[name] = {
        wallpaper: prefs.wallpaper,
        mode: prefs.mode
      };
      wallpaperChanged(name, prefs.wallpaper);
    }
  }

  function cleanupDisconnectedMonitors() {
    if (!MonitorService?.ready)
      return;
    const currentNames = new Set();
    const count = MonitorService.monitors?.count ?? 0;
    for (let i = 0; i < count; i++) {
      currentNames.add(MonitorService.monitors.get(i).name);
    }
    for (const name in monitorPrefs) {
      if (!currentNames.has(name)) {
        delete monitorPrefs[name];
        delete lastAnnounced[name];
      }
    }
  }

  function ensurePrefs(name) {
    if (!monitorPrefs[name]) {
      monitorPrefs[name] = {
        wallpaper: defaultWallpaper,
        mode: defaultMode
      };
    }
    return monitorPrefs[name];
  }

  function hydrateFromSettings() {
    if (!Settings?.data || hydrated)
      return;
    const saved = Settings.data.wallpapers ?? {};
    for (const name in saved) {
      const sp = saved[name] ?? {};
      monitorPrefs[name] = {
        wallpaper: sp.wallpaper || defaultWallpaper,
        mode: root.validMode(sp.mode)
      };
    }
    if (Settings.data.wallpaperTransition) {
      wallpaperTransition = root.validTransition(Settings.data.wallpaperTransition);
    }
    if (Settings.data.wallpaperFolder) {
      wallpaperFolder = String(Settings.data.wallpaperFolder);
    }
    if (Object.keys(monitorPrefs).length === 0 && MonitorService.ready) {
      root.seedCurrentMonitors();
    }
    hydrated = true;
    if (MonitorService.ready)
      root.announceAll();
    root.persistMonitors();
  }

  function modeToFillMode(mode) {
    const modes = {
      fill: 2,
      fit: 1,
      stretch: 3,
      center: 6,
      tile: 4
    };
    return modes[root.validMode(mode)] ?? 2;
  }

  function persistMonitors() {
    if (!hydrated || !Settings?.data || !MonitorService?.ready)
      return;
    const out = {};
    const count = MonitorService.monitors?.count ?? 0;
    for (let i = 0; i < count; i++) {
      const name = MonitorService.monitors.get(i).name;
      const p = monitorPrefs[name] ?? {};
      out[name] = {
        wallpaper: p.wallpaper || defaultWallpaper,
        mode: root.validMode(p.mode)
      };
    }
    const key = JSON.stringify([out, root.validTransition(wallpaperTransition)]);
    if (key === persistKey)
      return;
    persistKey = key;
    Settings.data.wallpapers = out;
    Settings.data.wallpaperTransition = root.validTransition(wallpaperTransition);
  }

  function randomizeAllMonitors() {
    if (!MonitorService?.ready || !wallpaperFilesReady)
      return;

    const files = wallpaperFiles.map(entry => entry.path).filter(p => !!p);
    if (!files.length) {
      console.warn("WallpaperService: no wallpaper files available in", wallpaperFolder);
      return;
    }

    const count = MonitorService.monitors.count;
    for (let i = 0; i < count; i++) {
      const mon = MonitorService.monitors.get(i);
      const chosen = files[Math.floor(Math.random() * files.length)];
      root.setWallpaper(mon.name, chosen);
    }
  }

  function seedCurrentMonitors() {
    if (!MonitorService?.ready)
      return;
    const count = MonitorService.monitors.count;
    for (let i = 0; i < count; i++) {
      root.ensurePrefs(MonitorService.monitors.get(i).name);
    }
  }

  function setModePref(name, mode) {
    if (!name)
      return;
    const p = root.ensurePrefs(name);
    const v = root.validMode(mode);
    if (p.mode === v)
      return;
    p.mode = v;
    modeChanged(name, p.mode);
    persistDebounce.restart();
  }

  function setWallpaper(name, path) {
    if (!name)
      return;
    const p = root.ensurePrefs(name);
    const v = path || defaultWallpaper;
    if (p.wallpaper === v)
      return;
    p.wallpaper = v;
    wallpaperChanged(name, p.wallpaper);
    persistDebounce.restart();
  }

  function setWallpaperFolder(folder) {
    const path = String(folder || "").replace(/\/$/, "");
    if (!path || wallpaperFolder === path)
      return;
    wallpaperFolder = path;
    if (Settings?.data)
      Settings.data.wallpaperFolder = wallpaperFolder;
  }

  function setWallpaperTransition(transition) {
    const v = root.validTransition(transition);
    if (wallpaperTransition === v)
      return;
    wallpaperTransition = v;
    transitionChanged(wallpaperTransition);
    if (Settings?.data)
      Settings.data.wallpaperTransition = wallpaperTransition;
  }

  function validMode(mode) {
    const normalized = String(mode ?? "").toLowerCase();
    return availableModes.includes(normalized) ? normalized : defaultMode;
  }

  function validTransition(t) {
    const normalized = String(t ?? "").toLowerCase();
    return availableTransitions.includes(normalized) ? normalized : defaultTransition;
  }

  function wallpaperFor(name) {
    if (!name || !ready)
      return null;
    const idx = MonitorService.findMonitorIndexByName(name);
    if (idx < 0)
      return null;
    const m = MonitorService.monitors.get(idx);
    const p = root.ensurePrefs(name);
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

  Component.onCompleted: {
    if (Settings?.isLoaded)
      root.hydrateFromSettings();
  }

  FolderListModel {
    id: wallpaperFolderModel

    folder: root.wallpaperFolder ? `file://${root.wallpaperFolder}` : ""
    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP"]
    showDirs: false
    showFiles: true

    onStatusChanged: {
      if (status === FolderListModel.Ready) {
        const list = [];
        for (let i = 0; i < count; i++) {
          const filePath = get(i, "filePath").toString().replace("file://", "");
          if (filePath) {
            const resolvedPath = filePath.startsWith("file:") ? filePath : `file://${filePath}`;
            const nameMatch = filePath.split("/").pop() || filePath;
            list.push({
              path: filePath,
              displayName: nameMatch,
              previewSource: resolvedPath
            });
          }
        }
        root.wallpaperFiles = list;
      }
    }
  }

  Timer {
    id: announceDebounce

    interval: 50
    repeat: false

    onTriggered: root.announceAll()
  }

  Timer {
    id: persistDebounce

    interval: 80
    repeat: false

    onTriggered: root.persistMonitors()
  }

  Connections {
    function onIsLoadedChanged() {
      if (Settings.isLoaded && !root.hydrated)
        root.hydrateFromSettings();
    }

    target: Settings
  }

  Connections {
    function onMonitorsUpdated() {
      if (MonitorService.ready && root.hydrated) {
        root.cleanupDisconnectedMonitors();
        root.seedCurrentMonitors();
        announceDebounce.restart();
        root.persistMonitors();
      }
    }

    function onReadyChanged() {
      if (MonitorService.ready && root.hydrated) {
        root.seedCurrentMonitors();
        announceDebounce.restart();
      }
    }

    target: MonitorService
  }
}
