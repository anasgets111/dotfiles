pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: root

  property string cacheDir: Quickshell.env("OBELISK_CACHE_DIR") || (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/" + shellName + "/"
  property string cacheDirImages: cacheDir + "images/"
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
        if (!isLoaded) {
          Logger.log("Settings", "JSON completed loading");
          isLoaded = true;
        }
      });
    }

    JsonAdapter {
      id: adapter

      // applauncher
      property JsonObject appLauncher: JsonObject {}

      // Per-monitor wallpaper preferences map (dynamic keys)
      // wallpapers: { "MONITOR_NAME": { wallpaper: string, mode: string } }
      property var wallpapers: ({})
      // Allowed values: "fade", "wipe", "disc", "stripes"
      property string wallpaperTransition: "disc"

      // Idle Service settings (persisted)
      // These defaults act as fallbacks if not present in the user's settings file
      property JsonObject idleService: JsonObject {
        // master enable for idle pipeline
        property bool enabled: true
        // lock stage
        property bool lockEnabled: true
        property int lockTimeoutSec: 300
        // dpms stage
        property bool dpmsEnabled: true
        property int dpmsTimeoutSec: 30
        // suspend stage
        property bool suspendEnabled: false
        property int suspendTimeoutSec: 120
        // behavior
        property bool respectInhibitors: true
        property bool videoAutoInhibit: true
      }
    }
  }
}
