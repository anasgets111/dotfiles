pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: root

  // ═══════════════════════════════════════════════════════════════════════════
  // COLOR SCHEME
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property string _colorSchemePath: Qt.resolvedUrl("../Assets/ColorScheme/" + (root.data?.themeName ?? "Catppuccin") + ".json")
  property var _loadedScheme: ({})
  readonly property string _xdgCache: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")
  readonly property string _xdgConfig: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  property list<string> availableThemes: []
  property string cacheDir: Quickshell.env("OBELISK_CACHE_DIR") || (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/" + shellName + "/"
  property string cacheDirImages: cacheDir + "images/"
  readonly property var colors: _loadedScheme?.[root.data?.themeMode ?? "dark"] ?? {}
  property string configDir: Quickshell.env("OBELISK_CONFIG_DIR") || (_xdgConfig + "/" + shellName + "/")
  property alias data: settingsAdapter
  property string defaultAvatar: Quickshell.env("HOME") + "/.face"
  property string defaultWallpaper: Qt.resolvedUrl("../Assets/3.jpg")

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════════════════════
  property bool isLoaded: false
  property bool isStateLoaded: false
  property string settingsFile: Quickshell.env("OBELISK_SETTINGS_FILE") || (configDir + "settings.json")

  // ═══════════════════════════════════════════════════════════════════════════
  // PATHS
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property string shellName: "Obelisk"
  property alias state: cacheAdapter
  property string stateFile: cacheDir + "state.json"

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════
  function saveState(): void {
    if (isStateLoaded)
      stateFileView.writeAdapter();
  }

  function setThemeMode(mode: string): void {
    const validMode = mode === "light" ? "light" : "dark";
    if (root.data?.themeMode !== validMode)
      root.data.themeMode = validMode;
  }

  function setThemeName(name: string): void {
    if (!name || root.data?.themeName === name)
      return;
    if (availableThemes.length && !availableThemes.includes(name)) {
      Logger.log("Settings", `Theme "${name}" not found, keeping "${root.data?.themeName ?? "Catppuccin"}"`, "warning");
      return;
    }
    root.data.themeName = name;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════
  Component.onCompleted: {
    Quickshell.execDetached(["mkdir", "-p", configDir, cacheDir, cacheDirImages]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COLOR SCHEME LOADER
  // ═══════════════════════════════════════════════════════════════════════════
  FileView {
    id: colorSchemeFileView

    path: root._colorSchemePath
    watchChanges: true

    Component.onCompleted: reload()
    onFileChanged: reload()
    onLoadFailed: error => {
      Logger.log("Settings", "Failed to load color scheme '" + (root.data?.themeName ?? "Catppuccin") + "': " + error + ". Falling back to Catppuccin.", "warning");
      if (root.data?.themeName !== "Catppuccin") {
        root.data.themeName = "Catppuccin";
        root.data.themeMode = "dark";
      }
    }
    onLoaded: {
      try {
        root._loadedScheme = JSON.parse(text());
        Logger.log("Settings", "Loaded color scheme: " + (root.data?.themeName ?? "Catppuccin") + "/" + (root.data?.themeMode ?? "dark"));
      } catch (e) {
        Logger.log("Settings", "Failed to parse color scheme JSON: " + e, "warning");
        root._loadedScheme = {};
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // THEME ENUMERATOR
  // ═══════════════════════════════════════════════════════════════════════════
  FolderListModel {
    id: themeEnumerator

    folder: Qt.resolvedUrl("../Assets/ColorScheme/")
    nameFilters: ["*.json"]
    showDirs: false

    onCountChanged: {
      const themes = [];
      for (let i = 0; i < count; i++)
        themes.push(get(i, "fileBaseName"));
      root.availableThemes = themes;
    }
  }

  JsonAdapter {
    id: settingsAdapter

    property JsonObject appLauncher: JsonObject {
    }
    property JsonObject idleService: JsonObject {
      property bool dpmsEnabled: true
      property int dpmsTimeoutSec: 30
      property bool enabled: true
      property bool lockAfterDpms: false
      property bool lockEnabled: true
      property int lockTimeoutSec: 300
      property bool respectInhibitors: true
      property bool suspendEnabled: false
      property int suspendTimeoutSec: 120
      property bool videoAutoInhibit: true
    }
    property JsonObject inputDisplay: JsonObject {
      property bool enabled: true
      property real positionXRatio: 0.06
      property real positionYRatio: 0.74
      property bool showPrintableKeys: false
    }
    property int overviewBlurMax: 64
    property real overviewBlurMultiplier: 2.0
    property real overviewBlurStrength: 0.6
    property string themeMode: "dark"
    property string themeName: "Catppuccin"
    property string wallpaperFolder: "/mnt/Work/1Wallpapers/Main"
    property string wallpaperTransition: "disc"
    property var wallpapers: ({})
    property JsonObject weatherLocation: JsonObject {
      property real latitude: 30.0507
      property real longitude: 31.2489
      property string placeName: "Cairo, Egypt"
    }
  }

  JsonAdapter {
    id: cacheAdapter

    property var currency: ({
        lastUpdate: "",
        rates: {}
      })
    property JsonObject updates: JsonObject {
      property string cachedUpdatePackagesJson: "[]"
      property int lastNotificationId: 0
      property double lastSync: 0
    }
    property JsonObject weather: JsonObject {
      property string dailyForecast: ""
      property string lastPollTimestamp: ""
      property string temperature: ""
      property int weatherCode: -1
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETTINGS PERSISTENCE
  // ═══════════════════════════════════════════════════════════════════════════
  Timer {
    id: saveTimer

    interval: 1000

    onTriggered: settingsFileView.writeAdapter()
  }

  FileView {
    id: settingsFileView

    adapter: settingsAdapter
    path: root.settingsFile
    watchChanges: true

    Component.onCompleted: reload()
    onAdapterUpdated: saveTimer.start()
    onFileChanged: reload()
    onLoadFailed: error => {
      if (error.toString().includes("No such file") || error === 2)
        writeAdapter();
    }
    onLoaded: {
      if (!root.isLoaded) {
        Logger.log("Settings", "JSON completed loading");
        root.isLoaded = true;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE PERSISTENCE
  // ═══════════════════════════════════════════════════════════════════════════
  Timer {
    id: saveStateTimer

    interval: 1000

    onTriggered: stateFileView.writeAdapter()
  }

  FileView {
    id: stateFileView

    adapter: cacheAdapter
    path: root.stateFile
    watchChanges: true

    Component.onCompleted: reload()
    onAdapterUpdated: saveStateTimer.start()
    onFileChanged: reload()
    onLoadFailed: error => {
      if (error.toString().includes("No such file") || error === 2)
        writeAdapter();
      root.isStateLoaded = true;
    }
    onLoaded: {
      if (!root.isStateLoaded) {
        Logger.log("Settings", "State JSON completed loading");
        root.isStateLoaded = true;
      }
    }
  }
}
