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
  readonly property list<string> availableModes: ["fill", "fit", "center", "stretch", "tile"]
  readonly property list<string> availableTransitions: ["fade", "wipe", "disc", "stripes", "portal"]
  readonly property string defaultMode: "fill"
  readonly property string defaultTransition: "disc"
  readonly property string defaultWallpaper: Settings.defaultWallpaper
  readonly property var fillModes: ({fill: Image.PreserveAspectCrop, fit: Image.PreserveAspectFit, stretch: Image.Stretch, tile: Image.Tile, center: Image.Pad})
  property bool hydrated: false
  property var monitorPrefs: ({})
  readonly property var monitors: ready ? Array.from(
    {length: MonitorService.monitors.count},
    (_unused, index) => {
      const monitor = MonitorService.monitors.get(index);
      return {name: monitor.name, scale: monitor.scale};
    }
  ) : []
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
    for (const name of Object.keys(saved)) {
      const entry = saved[name] ?? {};
      monitorPrefs[name] = {
        wallpaper: entry.wallpaper || defaultWallpaper,
        mode: validate(entry.mode, availableModes, defaultMode)
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
    return fillModes[validate(mode, availableModes, defaultMode)] ?? Image.PreserveAspectCrop;
  }

  function persistMonitors(): void {
    if (!hydrated || !Settings?.data || !MonitorService?.ready)
      return;
    const persisted = Object.assign({}, Settings.data.wallpapers ?? {});
    for (let index = 0; index < (MonitorService.monitors?.count ?? 0); index++) {
      const name = MonitorService.monitors.get(index).name;
      const prefs = monitorPrefs[name] ?? {};
      persisted[name] = {
        wallpaper: prefs.wallpaper || defaultWallpaper,
        mode: validate(prefs.mode, availableModes, defaultMode)
      };
    }
    Settings.data.wallpapers = persisted;
    Settings.data.wallpaperTransition = wallpaperTransition;
  }

  function randomizeAllMonitors(): void {
    if (!ready || !wallpaperFilesReady || !wallpaperFiles.length)
      return;
    for (let index = 0; index < MonitorService.monitors.count; index++) {
      const name = MonitorService.monitors.get(index).name;
      setWallpaper(name, wallpaperFiles[Math.floor(Math.random() * wallpaperFiles.length)].path);
    }
  }

  function setModePref(monitorName: string, mode: string): void {
    if (!monitorName)
      return;
    const prefs = getPrefs(monitorName);
    const validated = validate(mode, availableModes, defaultMode);
    if (prefs.mode === validated)
      return;
    prefs.mode = validated;
    _modeVersion++;
    persistDebounce.restart();
  }

  function setWallpaper(monitorName: string, path: string): void {
    if (!monitorName)
      return;
    const prefs = getPrefs(monitorName);
    const resolved = path || defaultWallpaper;
    if (prefs.wallpaper === resolved)
      return;
    prefs.wallpaper = resolved;
    _pathVersion++;
    persistDebounce.restart();
  }

  function setWallpaperFolder(folder: string): void {
    const path = String(folder || "").replace(/\/$/, "");
    if (!path || wallpaperFolder === path)
      return;
    wallpaperFolder = path;
    persistDebounce.restart();
  }

  function setWallpaperTransition(transition: string): void {
    const validated = validate(transition, availableTransitions, defaultTransition);
    if (wallpaperTransition === validated)
      return;
    wallpaperTransition = validated;
    persistDebounce.restart();
  }

  function validate(value: string, allowed: list<string>, fallback: string): string {
    const normalized = String(value ?? "").toLowerCase();
    return allowed.includes(normalized) ? normalized : fallback;
  }

  function wallpaperMode(monitorName: string): string {
    void _modeVersion;
    return monitorName ? getPrefs(monitorName).mode : defaultMode;
  }

  function wallpaperPath(monitorName: string): string {
    void _pathVersion;
    return monitorName ? getPrefs(monitorName).wallpaper : defaultWallpaper;
  }

  Component.onCompleted: if (Settings?.isLoaded)
    hydrateFromSettings()

  FolderListModel {
    id: folderModel

    caseSensitive: false
    folder: root.wallpaperFolder ? `file://${root.wallpaperFolder}` : ""
    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
    showDirs: false
    showFiles: true

    onStatusChanged: {
      if (status !== FolderListModel.Ready)
        return;
      root.wallpaperFiles = Array.from({length: count}, (_unused, index) => {
        const filePath = get(index, "filePath");
        return {path: filePath, displayName: filePath.split("/").pop(), previewSource: get(index, "fileUrl")};
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
