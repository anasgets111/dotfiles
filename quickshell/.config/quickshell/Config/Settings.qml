pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: root

  // ═══════════════════════════════════════════════════════════════════════════
  // COLOR SCHEME - Dynamic theme colors loaded from JSON
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property string _colorSchemePath: Qt.resolvedUrl("../Assets/ColorScheme/" + data.themeName + ".json")
  readonly property var _fallbackColors: ({})
  property var _loadedScheme: ({})

  // List of available theme names (populated by scanning ColorScheme folder)
  property list<string> availableThemes: []
  property string cacheDir: Quickshell.env("OBELISK_CACHE_DIR") || (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/" + shellName + "/"
  property string cacheDirImages: cacheDir + "images/"

  // Currently active color palette (dark or light based on themeMode)
  readonly property var colors: {
    const scheme = _loadedScheme;
    const mode = data.themeMode;
    return (scheme && scheme[mode]) ? scheme[mode] : _fallbackColors;
  }
  property string configDir: Quickshell.env("OBELISK_CONFIG_DIR") || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/" + shellName + "/"

  // Used to access via Settings.data.xxx.yyy
  property alias data: adapter
  property string defaultAvatar: Quickshell.env("HOME") + "/.face"
  property string defaultWallpaper: Qt.resolvedUrl("../Assets/3.jpg")
  property bool isLoaded: false
  property string settingsFile: Quickshell.env("OBELISK_SETTINGS_FILE") || (configDir + "settings.json")

  // Define our app directories
  // Default config directory: ~/.config/Obelisk
  // Default cache directory: ~/.cache/Obelisk
  property string shellName: "Obelisk"

  // Set theme mode ("dark" or "light")
  function setThemeMode(mode: string): void {
    const validMode = (mode === "light") ? "light" : "dark";
    if (root.data.themeMode !== validMode)
      root.data.themeMode = validMode;
  }

  function setThemeName(name: string): void {
    if (!name || root.data.themeName === name)
      return;
    // Validate theme exists, fallback to current if invalid
    if (root.availableThemes.length && !root.availableThemes.includes(name)) {
      Logger.log("Settings", `Theme "${name}" not found, keeping "${root.data.themeName}"`, "warning");
      return;
    }
    root.data.themeName = name;
  }

  Item {
    Component.onCompleted: {
      // ensure settings dir exists
      Quickshell.execDetached(["mkdir", "-p", root.configDir]);
      Quickshell.execDetached(["mkdir", "-p", root.cacheDir]);
      Quickshell.execDetached(["mkdir", "-p", root.cacheDirImages]);
      // enumerate available themes
      themeEnumerator.running = true;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COLOR SCHEME LOADER - Reads theme JSON files
  // ═══════════════════════════════════════════════════════════════════════════
  FileView {
    id: colorSchemeFileView

    path: root._colorSchemePath
    watchChanges: true

    Component.onCompleted: reload()
    onFileChanged: reload()
    onLoadFailed: error => {
      Logger.log("Settings", "Failed to load color scheme '" + adapter.themeName + "': " + error + ". Falling back to Catppuccin.", "warning");
      // Fall back to Catppuccin if current theme fails
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

  // Enumerate available themes from ColorScheme folder
  Process {
    id: themeEnumerator

    command: ["sh", "-c", "ls -1 '" + Qt.resolvedUrl("../Assets/ColorScheme/").toString().replace("file://", "") + "' | sed 's/\\.json$//'"]
    running: false

    stdout: SplitParser {
      onRead: data => {
        if (data.trim())
          root.availableThemes = root.availableThemes.concat([data.trim()]);
      }
    }
  }

  // Don't write settings to disk immediately
  // This avoid excessive IO when a variable changes rapidly (ex: sliders)
  Timer {
    id: saveTimer

    interval: 1000
    running: false

    onTriggered: settingsFileView.writeAdapter()
  }

  FileView {
    id: settingsFileView

    path: root.settingsFile
    watchChanges: true

    Component.onCompleted: function () {
      reload();
    }
    onAdapterUpdated: saveTimer.start()
    onFileChanged: reload()
    onLoadFailed: function (error) {
      if (error.toString().includes("No such file") || error === 2)
        // File doesn't exist, create it with default values
        writeAdapter();
    }
    onLoaded: function () {
      if (!root.isLoaded) {
        Logger.log("Settings", "JSON completed loading");
        root.isLoaded = true;
      }
    }

    JsonAdapter {
      id: adapter

      // applauncher
      property JsonObject appLauncher: JsonObject {
      }

      // Idle Service settings (persisted)
      // These defaults act as fallbacks if not present in the user's settings file
      property JsonObject idleService: JsonObject {
        // dpms stage
        property bool dpmsEnabled: true
        property int dpmsTimeoutSec: 30
        // master enable for idle pipeline
        property bool enabled: true
        // lock stage
        property bool lockEnabled: true
        property int lockTimeoutSec: 300
        // behavior
        property bool respectInhibitors: true
        // suspend stage
        property bool suspendEnabled: false
        property int suspendTimeoutSec: 120
        property bool videoAutoInhibit: true
      }

      // Theme settings
      property string themeMode: "dark"   // "dark" or "light"
      property string themeName: "Catppuccin"

      // Wallpaper folder path for browsing/randomization
      property string wallpaperFolder: "/mnt/Work/1Wallpapers/Main"
      // Allowed values: "fade", "wipe", "disc", "stripes"
      property string wallpaperTransition: "disc"

      // Per-monitor wallpaper preferences map (dynamic keys)
      // wallpapers: { "MONITOR_NAME": { wallpaper: string, mode: string } }
      property var wallpapers: ({})

      // Weather location and last poll data
      property JsonObject weatherLocation: JsonObject {
        property string dailyForecast: ""
        property string lastPollTimestamp: ""  // ISO 8601 format
        property real latitude: 30.0507
        property real longitude: 31.2489
        property string placeName: "Cairo, Egypt"
        property string temperature: ""
        property int weatherCode: -1
      }
    }
  }
}
