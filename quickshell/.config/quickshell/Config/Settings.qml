pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils
import qs.Services.Core

Singleton {
  id: root

  property string cacheDir: Quickshell.env("OBELISK_CACHE_DIR") || (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/" + shellName + "/"
  property string cacheDirImages: cacheDir + "images/"
  property string configDir: Quickshell.env("OBELISK_CONFIG_DIR") || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/" + shellName + "/"

  // Used to access via Settings.data.xxx.yyy
  property alias data: adapter
  property string defaultAvatar: Quickshell.env("HOME") + "/.face"
  property string defaultWallpaper: Qt.resolvedUrl("../Assets/Tests/3.jpg")
  property bool isLoaded: false
  property string settingsFile: Quickshell.env("OBELISK_SETTINGS_FILE") || (configDir + "settings.json")

  // Define our app directories
  // Default config directory: ~/.config/Obelisk
  // Default cache directory: ~/.cache/Obelisk
  property string shellName: "Obelisk"

  Item {
    Component.onCompleted: {

      // ensure settings dir exists
      Quickshell.execDetached(["mkdir", "-p", root.configDir]);
      Quickshell.execDetached(["mkdir", "-p", root.cacheDir]);
      Quickshell.execDetached(["mkdir", "-p", root.cacheDirImages]);
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

    // Function to validate monitor configurations
    function validateMonitorConfigurations() {
      var availableScreenNames = [];
      for (var i = 0; i < Quickshell.screens.length; i++) {
        availableScreenNames.push(Quickshell.screens[i].name);
      }

      Logger.log("Settings", "Available monitors: [" + availableScreenNames.join(", ") + "]");
      Logger.log("Settings", "Configured bar monitors: [" + adapter.bar.monitors.join(", ") + "]");

      // Check bar monitors
      if (adapter.bar.monitors.length > 0) {
        var hasValidBarMonitor = false;
        for (var j = 0; j < adapter.bar.monitors.length; j++) {
          if (availableScreenNames.includes(adapter.bar.monitors[j])) {
            hasValidBarMonitor = true;
            break;
          }
        }
        if (!hasValidBarMonitor) {
          Logger.log("Settings", "No configured bar monitors found on system, clearing bar monitor list to show on all screens");
          adapter.bar.monitors = [];
        } else {
          Logger.log("Settings", "Found valid bar monitors, keeping configuration");
        }
      } else {
        Logger.log("Settings", "Bar monitor list is empty, will show on all available screens");
      }
    }

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
      Qt.callLater(function () {
        // Some stuff like wallpaper setup and settings validation should just be executed once on startup
        // And not on every reload
        if (!isLoaded) {
          Logger.log("Settings", "JSON completed loading");
          if (adapter.wallpaper.current !== "") {
            Logger.log("Settings", "Set current wallpaper", adapter.wallpaper.current);
            WallpaperService.setCurrentWallpaper(adapter.wallpaper.current, true);
          }

          isLoaded = true;
        }
      });
    }

    JsonAdapter {
      id: adapter

      // applauncher
      property JsonObject appLauncher: JsonObject {
        property real backgroundOpacity: 1.0
        // When disabled, Launcher hides clipboard command and ignores cliphist
        property bool enableClipboardHistory: true
        property list<string> pinnedExecs: []
        // Position: center, top_left, top_right, bottom_left, bottom_right, bottom_center, top_center
        property string position: "center"
      }

      // audio
      property JsonObject audio: JsonObject {
        property int cavaFrameRate: 60
        // MPRIS controls
        property list<string> mprisBlacklist: []
        property string preferredPlayer: ""
        property bool showMiniplayerAlbumArt: false
        property bool showMiniplayerCava: false
        property string visualizerType: "linear"
        property int volumeStep: 5
      }

      // bar
      property JsonObject bar: JsonObject {
        property bool alwaysShowBatteryPercentage: false
        property real backgroundOpacity: 1.0
        property list<string> monitors: []
        property string position: "top" // Possible values: "top", "bottom"
        property bool showActiveWindowIcon: true
        property string showWorkspaceLabel: "none"

        // Widget configuration for modular bar system
        property JsonObject widgets: JsonObject {
          property list<string> center: ["Workspace"]
          property list<string> left: ["SystemMonitor", "ActiveWindow", "MediaMini"]
          property list<string> right: ["ScreenRecorderIndicator", "Tray", "NotificationHistory", "WiFi", "Bluetooth", "Battery", "Volume", "Brightness", "NightLight", "Clock", "SidePanelToggle"]
        }
      }

      // brightness
      property JsonObject brightness: JsonObject {
        property int brightnessStep: 5
      }
      property JsonObject colorSchemes: JsonObject {
        property bool darkMode: true
        property string predefinedScheme: ""
        // External app theming (GTK & Qt)
        property bool themeApps: false
        property bool useWallpaperColors: false
      }

      // dock
      property JsonObject dock: JsonObject {
        property bool autoHide: false
        property bool exclusive: false
        property list<string> monitors: []
      }

      // general
      property JsonObject general: JsonObject {
        property string avatarImage: root.defaultAvatar
        property bool dimDesktop: false
        property real radiusRatio: 1.0
        property bool showScreenCorners: false
        // Replace sidepanel toggle with distro logo (shown in bar and/or side panel)
        property bool useDistroLogoForSidepanel: false
      }

      // location
      property JsonObject location: JsonObject {
        property string name: "Tokyo"
        property bool reverseDayMonth: false
        property bool showDateWithClock: false
        property bool use12HourClock: false
        property bool useFahrenheit: false
      }

      // Scaling (not stored inside JsonObject, or it crashes)
      property var monitorsScaling: {}

      // network
      property JsonObject network: JsonObject {
        property bool bluetoothEnabled: true
        property bool wifiEnabled: true
      }

      // night light
      property JsonObject nightLight: JsonObject {
        property bool autoSchedule: false
        property bool enabled: false
        property real intensity: 0.8
        property string startTime: "20:00"
        property string stopTime: "07:00"
      }

      // notifications
      property JsonObject notifications: JsonObject {
        property list<string> monitors: []
      }

      // screen recorder
      property JsonObject screenRecorder: JsonObject {
        property string audioCodec: "opus"
        property string audioSource: "default_output"
        property string colorRange: "limited"
        property string directory: "~/Videos"
        property int frameRate: 60
        property string quality: "very_high"
        property bool showCursor: true
        property string videoCodec: "h264"
        property string videoSource: "portal"
      }

      // ui
      property JsonObject ui: JsonObject {
        property string fontBillboard: "Inter" // Large bold font for clocks and prominent displays

        property string fontDefault: "Roboto" // Default font for all text

        // Legacy compatibility
        property string fontFamily: fontDefault // Keep for backward compatibility

        property string fontFixed: "DejaVu Sans Mono" // Fixed width font for terminal

        // Idle inhibitor state
        property bool idleInhibitorEnabled: false
      }

      // wallpaper
      property JsonObject wallpaper: JsonObject {
        property string current: ""
        property string directory: "/usr/share/wallpapers"
        property bool isRandom: false
        property int randomInterval: 300
        property JsonObject swww: JsonObject {
          property bool enabled: false
          property string resizeMethod: "crop"
          property real transitionDuration: 1.1
          property int transitionFps: 60
          property string transitionType: "random"
        }
      }
    }
  }
}
