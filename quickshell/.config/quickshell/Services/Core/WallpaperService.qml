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
  readonly property var fillModeMap: ({
      fill: 2,
      fit: 1,
      stretch: 3,
      center: 6,
      tile: 4
    })
  property bool hydrated: false
  property var monitorPrefs: ({})
  property list<var> monitors: []
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
      wallpaperChanged(name, prefs.wallpaper);
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
    hydrated = true;
    if (MonitorService.ready) {
      root.rebuildMonitors();
      root.announceAll();
    }
    root.persistMonitors();
  }

  function modeToFillMode(mode) {
    return fillModeMap[root.validMode(mode)] ?? 2;
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
    Settings.data.wallpapers = out;
    Settings.data.wallpaperTransition = root.validTransition(wallpaperTransition);
  }

  function randomizeAllMonitors() {
    if (!MonitorService?.ready || !wallpaperFilesReady)
      return;

    if (!wallpaperFiles.length) {
      console.warn("WallpaperService: no wallpaper files available in", wallpaperFolder);
      return;
    }

    const count = MonitorService.monitors.count;
    for (let i = 0; i < count; i++) {
      const mon = MonitorService.monitors.get(i);
      const chosen = wallpaperFiles[Math.floor(Math.random() * wallpaperFiles.length)].path;
      root.setWallpaper(mon.name, chosen);
    }
  }

  function rebuildMonitors() {
    if (!ready) {
      monitors = [];
      return;
    }
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
    monitors = out;
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
    root.rebuildMonitors();
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
        // Pre-allocate array for better memory performance
        const list = new Array(count);
        let validCount = 0;

        for (let i = 0; i < count; i++) {
          const filePath = get(i, "filePath").toString().replace("file://", "");
          if (filePath) {
            const resolvedPath = filePath.startsWith("file:") ? filePath : `file://${filePath}`;
            const nameMatch = filePath.split("/").pop() || filePath;
            list[validCount++] = {
              path: filePath,
              displayName: nameMatch,
              previewSource: resolvedPath
            };
          }
        }

        // Trim array to actual valid count if needed
        if (validCount < count) {
          list.length = validCount;
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
        root.rebuildMonitors();
        root.persistMonitors();
      }
    }

    function onReadyChanged() {
      if (MonitorService.ready && root.hydrated) {
        root.rebuildMonitors();
      }
    }

    target: MonitorService
  }
}
