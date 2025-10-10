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

  WlSessionLock {
    id: sessionLock
    locked: LockService.locked

    WlSessionLockSurface {
      id: lockSurface

      readonly property string screenName: screen?.name || ""
      readonly property bool hasScreen: !!screen
      readonly property bool isMainMonitor: hasScreen && MonitorService?.activeMain === screenName
      readonly property var wallpaperData: hasScreen && screenName ? WallpaperService.wallpaperFor(screenName) : null
      readonly property int wallpaperFillMode: WallpaperService.modeToFillMode(wallpaperData?.mode)

      color: "transparent"

      Loader {
        id: contentLoader
        anchors.fill: parent
        active: lockSurface.hasScreen
        asynchronous: true
        sourceComponent: FocusScope {
          anchors.fill: parent
          focus: true

          // Global keyboard event handler - always active when lock screen is visible
          Keys.onPressed: event => {
            if (LockService && LockService.handleGlobalKeyPress(event)) {
              event.accepted = true;
            }
          }

          Component.onCompleted: {
            forceActiveFocus();
          }

          Item {
            anchors.fill: parent

            Image {
              anchors.fill: parent
              fillMode: lockSurface.wallpaperFillMode
              layer.enabled: lockSurface.hasScreen
              cache: false
              mipmap: false
              source: lockSurface.wallpaperData?.wallpaper || ""
              visible: lockSurface.hasScreen
              layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blur: 0.9
                blurEnabled: true
                blurMax: 64
                blurMultiplier: 1
              }
            }

            LockContent {
              id: lockContent
              lockContext: LockService
              lockSurface: lockSurface
              theme: root.theme
            }
          }
        }
      }

      // one day :D
      // ScreencopyView {
      //   id: background
      //   anchors.fill: parent
      //   captureSource: lockSurface.screen
      //   layer.enabled: true
      //   layer.effect: MultiEffect {
      //     autoPaddingEnabled: false
      //     blurEnabled: true
      //     blur: 0.9
      //     blurMax: 64
      //     blurMultiplier: 1
      //   }
      // }
    }
  }
}
