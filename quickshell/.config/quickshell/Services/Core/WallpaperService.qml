pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.Config
import qs.Services.WM

Singleton {
  id: root

  property int _modeVersion: 0
  property int _pathVersion: 0
  property int _transitionVersion: 0
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
  readonly property var monitors: ready ? Array.from({
    length: MonitorService.monitors.count
  }, (_, i) => {
    const m = MonitorService.monitors.get(i);
    return {
      name: m.name,
      scale: m.scale
    };
  }) : []
  readonly property string overviewNamespace: "quickshell-overview-wallpaper"
  readonly property bool ready: hydrated && MonitorService?.ready && (MonitorService.monitors?.count ?? 0) > 0
  property var wallpaperFiles: []
  readonly property bool wallpaperFilesReady: folderModel.status === FolderListModel.Ready
  property string wallpaperFolder: "/mnt/Work/1Wallpapers/Main"
  property string wallpaperTransition: defaultTransition

  function getPrefs(monitorName: string): var {
    return monitorPrefs[monitorName] ?? (monitorPrefs[monitorName] = {
        wallpaper: defaultWallpaper,
        mode: defaultMode
      });
  }

  function hydrateFromSettings(): void {
    if (!Settings?.data || hydrated)
      return;
    const saved = Settings.data.wallpapers ?? {};
    for (const name in saved) {
      const sp = saved[name] ?? {};
      monitorPrefs[name] = {
        wallpaper: sp.wallpaper || defaultWallpaper,
        mode: validate(sp.mode, availableModes, defaultMode)
      };
    }
    if (Settings.data.wallpaperTransition)
      wallpaperTransition = validate(Settings.data.wallpaperTransition, availableTransitions, defaultTransition);
    if (Settings.data.wallpaperFolder)
      wallpaperFolder = String(Settings.data.wallpaperFolder);
    hydrated = true;
    persistMonitors();
  }

  function modeToFillMode(mode: string): int {
    return fillModeMap[validate(mode, availableModes, defaultMode)] ?? 2;
  }

  function persistMonitors(): void {
    if (!hydrated || !Settings?.data || !MonitorService?.ready)
      return;
    const out = Object.assign({}, Settings.data.wallpapers ?? {});
    for (let i = 0; i < (MonitorService.monitors?.count ?? 0); i++) {
      const name = MonitorService.monitors.get(i).name;
      const p = monitorPrefs[name] ?? {};
      out[name] = {
        wallpaper: p.wallpaper || defaultWallpaper,
        mode: validate(p.mode, availableModes, defaultMode)
      };
    }
    Settings.data.wallpapers = out;
    Settings.data.wallpaperTransition = wallpaperTransition;
  }

  function randomizeAllMonitors(): void {
    if (!ready || !wallpaperFilesReady || !wallpaperFiles.length)
      return;
    for (let i = 0; i < MonitorService.monitors.count; i++) {
      const name = MonitorService.monitors.get(i).name;
      setWallpaper(name, wallpaperFiles[Math.floor(Math.random() * wallpaperFiles.length)].path);
    }
  }

  function setModePref(monitorName: string, mode: string): void {
    if (!monitorName)
      return;
    const p = getPrefs(monitorName);
    const v = validate(mode, availableModes, defaultMode);
    if (p.mode === v)
      return;
    p.mode = v;
    _modeVersion++;
    persistDebounce.restart();
  }

  function setWallpaper(monitorName: string, path: string): void {
    if (!monitorName)
      return;
    const p = getPrefs(monitorName);
    const v = path || defaultWallpaper;
    if (p.wallpaper === v)
      return;
    p.wallpaper = v;
    _pathVersion++;
    persistDebounce.restart();
  }

  function setWallpaperFolder(folder: string): void {
    const path = String(folder || "").replace(/\/$/, "");
    if (!path || wallpaperFolder === path)
      return;
    wallpaperFolder = path;
    if (Settings?.data)
      Settings.data.wallpaperFolder = path;
  }

  function setWallpaperTransition(transition: string): void {
    const v = validate(transition, availableTransitions, defaultTransition);
    if (wallpaperTransition === v)
      return;
    wallpaperTransition = v;
    _transitionVersion++;
    if (Settings?.data)
      Settings.data.wallpaperTransition = v;
  }

  function validate(value: string, allowed: list<string>, fallback: string): string {
    const v = String(value ?? "").toLowerCase();
    return allowed.includes(v) ? v : fallback;
  }

  function wallpaperMode(monitorName: string): string {
    void _modeVersion;
    return getPrefs(monitorName).mode ?? defaultMode;
  }

  function wallpaperPath(monitorName: string): string {
    void _pathVersion;
    return getPrefs(monitorName).wallpaper ?? defaultWallpaper;
  }

  function wallpaperTransitionType(): string {
    void _transitionVersion;
    return wallpaperTransition;
  }

  Component.onCompleted: if (Settings?.isLoaded)
    hydrateFromSettings()

  FolderListModel {
    id: folderModel

    folder: root.wallpaperFolder ? `file://${root.wallpaperFolder}` : ""
    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP"]
    showDirs: false
    showFiles: true

    onStatusChanged: {
      if (status !== FolderListModel.Ready)
        return;
      root.wallpaperFiles = Array.from({
        length: count
      }, (_, i) => {
        const path = get(i, "filePath").toString().replace("file://", "");
        return {
          path,
          displayName: path.split("/").pop(),
          previewSource: `file://${path}`
        };
      });
    }
  }

  Timer {
    id: persistDebounce

    interval: 80
    repeat: false

    onTriggered: root.persistMonitors()
  }

  Connections {
    function onIsLoadedChanged(): void {
      if (Settings.isLoaded && !root.hydrated)
        root.hydrateFromSettings();
    }

    target: Settings
  }

  Connections {
    function onMonitorsUpdated(): void {
      if (MonitorService.ready && root.hydrated)
        root.persistMonitors();
    }

    target: MonitorService
  }
}
