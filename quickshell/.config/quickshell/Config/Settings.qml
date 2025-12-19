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
  readonly property string _colorSchemePath: Qt.resolvedUrl("../Assets/ColorScheme/" + data.themeName + ".json")
  property var _loadedScheme: ({})
  readonly property string _xdgCache: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")
  readonly property string _xdgConfig: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  property list<string> availableThemes: []
  property string cacheDir: Quickshell.env("OBELISK_CACHE_DIR") || (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/" + shellName + "/"
  property string cacheDirImages: cacheDir + "images/"
  readonly property var colors: _loadedScheme?.[data.themeMode] ?? {}
  property string configDir: Quickshell.env("OBELISK_CONFIG_DIR") || (_xdgConfig + "/" + shellName + "/")
  property alias data: adapter
  property string defaultAvatar: Quickshell.env("HOME") + "/.face"
  property string defaultWallpaper: Qt.resolvedUrl("../Assets/3.jpg")

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════════════════════
  property bool isLoaded: false
  property string settingsFile: Quickshell.env("OBELISK_SETTINGS_FILE") || (configDir + "settings.json")

  // ═══════════════════════════════════════════════════════════════════════════
  // PATHS
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property string shellName: "Obelisk"

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════
  function setThemeMode(mode: string): void {
    const validMode = mode === "light" ? "light" : "dark";
    if (data.themeMode !== validMode)
      data.themeMode = validMode;
  }

  function setThemeName(name: string): void {
    if (!name || data.themeName === name)
      return;
    if (availableThemes.length && !availableThemes.includes(name)) {
      Logger.log("Settings", `Theme "${name}" not found, keeping "${data.themeName}"`, "warning");
      return;
    }
    data.themeName = name;
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
      Logger.log("Settings", "Failed to load color scheme '" + adapter.themeName + "': " + error + ". Falling back to Catppuccin.", "warning");
      if (adapter.themeName !== "Catppuccin") {
        adapter.themeName = "Catppuccin";
        adapter.themeMode = "dark";
      }
    }
    onLoaded: {
      try {
        root._loadedScheme = JSON.parse(text());
        Logger.log("Settings", "Loaded color scheme: " + adapter.themeName + "/" + adapter.themeMode);
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

    JsonAdapter {
      id: adapter

      property JsonObject appLauncher: JsonObject {
      }
      property JsonObject idleService: JsonObject {
        property bool dpmsEnabled: true
        property int dpmsTimeoutSec: 30
        property bool enabled: true
        property bool lockEnabled: true
        property int lockTimeoutSec: 300
        property bool respectInhibitors: true
        property bool suspendEnabled: false
        property int suspendTimeoutSec: 120
        property bool videoAutoInhibit: true
      }
      property string themeMode: "dark"
      property string themeName: "Catppuccin"
      property string wallpaperFolder: "/mnt/Work/1Wallpapers/Main"
      property string wallpaperTransition: "disc"
      property var wallpapers: ({})
      property JsonObject weatherLocation: JsonObject {
        property string dailyForecast: ""
        property string lastPollTimestamp: ""
        property real latitude: 30.0507
        property real longitude: 31.2489
        property string placeName: "Cairo, Egypt"
        property string temperature: ""
        property int weatherCode: -1
      }
    }
  }
}
