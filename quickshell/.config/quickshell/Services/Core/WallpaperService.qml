pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.Config
import qs.Services.Utils
import qs.Services.WM

Singleton {
  id: root

  readonly property list<string> availableModes: ["fill", "fit", "center", "stretch", "tile"]
  readonly property list<string> availableTransitions: ["fade", "wipe", "disc", "stripes", "portal"]
  readonly property string defaultMode: "fill"
  readonly property string defaultTransition: "disc"
  readonly property string defaultWallpaper: Utils.normalizeImageUrl(Settings.defaultWallpaper)
  readonly property var fillModes: ({
      fill: Image.PreserveAspectCrop,
      fit: Image.PreserveAspectFit,
      stretch: Image.Stretch,
      tile: Image.Tile,
      center: Image.Pad
    })
  readonly property var monitors: ready ? Array.from({
    length: MonitorService.monitors.count
  }, (_unused, index) => {
    const monitor = MonitorService.monitors.get(index);
    return {
      name: monitor.name,
      scale: monitor.scale
    };
  }) : []
  readonly property string overviewNamespace: "quickshell-overview-wallpaper"
  readonly property bool ready: Settings.isLoaded && MonitorService?.ready && (MonitorService.monitors?.count ?? 0) > 0
  property var wallpaperFiles: []
  readonly property bool wallpaperFilesReady: folderModel.status === FolderListModel.Ready
  readonly property string wallpaperFolder: Settings.data?.wallpaperFolder ?? ""
  readonly property string wallpaperTransition: validate(Settings.data?.wallpaperTransition, availableTransitions, defaultTransition)

  function modeToFillMode(mode: string): int {
    return fillModes[validate(mode, availableModes, defaultMode)] ?? Image.PreserveAspectCrop;
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
    if (!monitorName || !Settings?.data)
      return;
    const saved = Settings.data.wallpapers ?? {};
    const prefs = saved[monitorName] ?? {};
    const validated = validate(mode, availableModes, defaultMode);
    if (validate(prefs.mode, availableModes, defaultMode) === validated)
      return;
    const updated = Object.assign({}, saved);
    updated[monitorName] = {
      wallpaper: Utils.normalizeImageUrl(prefs.wallpaper || defaultWallpaper),
      mode: validated
    };
    Settings.data.wallpapers = updated;
  }
  function setWallpaper(monitorName: string, path: string): void {
    if (!monitorName || !Settings?.data)
      return;
    const saved = Settings.data.wallpapers ?? {};
    const prefs = saved[monitorName] ?? {};
    const resolved = Utils.normalizeImageUrl(path || defaultWallpaper);
    if (Utils.normalizeImageUrl(prefs.wallpaper || defaultWallpaper) === resolved)
      return;
    const updated = Object.assign({}, saved);
    updated[monitorName] = {
      wallpaper: resolved,
      mode: validate(prefs.mode, availableModes, defaultMode)
    };
    Settings.data.wallpapers = updated;
  }
  function setWallpaperFolder(folder: string): void {
    const rawPath = String(folder || "").trim();
    const path = rawPath === "/" ? rawPath : rawPath.replace(/\/+$/, "");
    if (!path || wallpaperFolder === path)
      return;
    Settings.data.wallpaperFolder = path;
  }
  function setWallpaperTransition(transition: string): void {
    if (!Settings?.data)
      return;
    const validated = validate(transition, availableTransitions, defaultTransition);
    if (wallpaperTransition === validated)
      return;
    Settings.data.wallpaperTransition = validated;
  }
  function validate(value: string, allowed: list<string>, fallback: string): string {
    const normalized = String(value ?? "").toLowerCase();
    return allowed.includes(normalized) ? normalized : fallback;
  }
  function wallpaperMode(monitorName: string): string {
    return monitorName ? validate(Settings.data?.wallpapers?.[monitorName]?.mode, availableModes, defaultMode) : defaultMode;
  }
  function wallpaperPath(monitorName: string): string {
    return monitorName ? Utils.normalizeImageUrl(Settings.data?.wallpapers?.[monitorName]?.wallpaper || defaultWallpaper) : defaultWallpaper;
  }

  onWallpaperFolderChanged: wallpaperFiles = []

  FolderListModel {
    id: folderModel

    caseSensitive: false
    folder: Utils.normalizeImageUrl(root.wallpaperFolder)
    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
    showDirs: false
    showFiles: true

    onStatusChanged: {
      if (status !== FolderListModel.Ready)
        return;
      root.wallpaperFiles = Array.from({
        length: count
      }, (_unused, index) => {
        const filePath = get(index, "filePath");
        return {
          path: String(get(index, "fileUrl")),
          displayName: filePath.split("/").pop(),
          previewSource: get(index, "fileUrl")
        };
      });
    }
  }
}
