pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Effects
import qs.Services.Core
import qs.Services.WM

Scope {
  id: root

  readonly property var theme: ({
      base: "#1e1e2e",
      mantle: "#181825",
      crust: "#11111b",
      surface0: "#313244",
      surface1: "#45475a",
      surface2: "#585b70",
      overlay0: "#6c7086",
      overlay1: "#7f849c",
      overlay2: "#9399b2",
      subtext0: "#a6adc8",
      subtext1: "#bac2de",
      text: "#cdd6f4",
      love: "#f38ba8",
      mauve: "#cba6f7"
    })

  QtObject {
    id: lockContextProxy

    property string authState: LockService.authState
    property bool authenticating: LockService.authenticating
    // forward LockService observable state via bindings; mutators provided below
    property string passwordBuffer: LockService.passwordBuffer
    property var theme: root.theme

    function setPasswordBuffer(v) {
      LockService.passwordBuffer = v;
    }

    function submitOrStart() {
      LockService.submitOrStart();
    }
  }

  WlSessionLock {
    id: sessionLock

    locked: LockService.locked

    WlSessionLockSurface {
      id: lockSurface

      readonly property bool blurDisabled: Quickshell.env("QS_DISABLE_LOCK_BLUR") === "1"
      readonly property bool hasScreen: !!lockSurface.screen
      readonly property bool isMainMonitor: !!(lockSurface.screen && MonitorService && MonitorService.activeMain === lockSurface.screen.name)
      readonly property var screenWallpaper: WallpaperService ? WallpaperService.wallpaperFor(lockSurface.screen) : null

      color: "transparent"

      Loader {
        id: wallpaperLoader
        anchors.fill: parent
        active: lockSurface.hasScreen
        sourceComponent: Image {
          anchors.fill: parent
          fillMode: {
            const mode = lockSurface.screenWallpaper ? lockSurface.screenWallpaper.mode : "fill";
            switch (mode) {
            case "fill":
              return Image.PreserveAspectCrop;
            case "fit":
              return Image.PreserveAspectFit;
            case "stretch":
              return Image.Stretch;
            case "center":
              return Image.Pad;
            case "tile":
              return Image.Tile;
            default:
              return Image.PreserveAspectCrop;
            }
          }
          layer.enabled: lockSurface.hasScreen && !lockSurface.blurDisabled
          layer.mipmap: false
          // Avoid retaining decoded images globally
          cache: false
          // Avoid extra texture levels
          mipmap: false
          sourceSize: Qt.size(width, height)
          source: WallpaperService.ready && lockSurface.screenWallpaper && lockSurface.screenWallpaper.wallpaper ? lockSurface.screenWallpaper.wallpaper : ""
          visible: lockSurface.hasScreen

          layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blur: 0.9
            blurEnabled: true
            blurMax: 64
            blurMultiplier: 1
          }
        }
      }

      MouseArea {
        acceptedButtons: Qt.NoButton
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true

        onEntered: lockContent.forceActiveFocus()
      }

      // one day :D
      // ScreencopyView {
      //     id: background
      //     anchors.fill: parent
      //     captureSource: surface.screen
      //     layer.enabled: true
      //     layer.effect: MultiEffect {
      //         autoPaddingEnabled: false
      //         blurEnabled: true
      //         blur: 0.75
      //         blurMax: 48
      //         blurMultiplier: 1
      //     }
      // }

      LockContent {
        id: lockContent

        // Provide theme + LockService auth state/methods
        lockContext: lockContextProxy
        lockSurface: lockSurface
      }
    }
  }
}
