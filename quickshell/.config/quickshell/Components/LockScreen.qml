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

      readonly property var screenRef: screen
      readonly property string screenName: screenRef && screenRef.name ? screenRef.name : ""
      readonly property bool hasScreen: !!screenRef
      readonly property bool isMainMonitor: hasScreen && MonitorService && MonitorService.activeMain === screenName
      readonly property var wallpaperData: hasScreen && WallpaperService ? (screenName ? WallpaperService.wallpaperFor(screenName) : ({
            wallpaper: WallpaperService.defaultWallpaper,
            mode: WallpaperService.defaultMode
          })) : null
      readonly property int wallpaperFillMode: ({
          fill: Image.PreserveAspectCrop,
          fit: Image.PreserveAspectFit,
          stretch: Image.Stretch,
          center: Image.Pad,
          tile: Image.Tile
        }[(wallpaperData && wallpaperData.mode) ? wallpaperData.mode : "fill"]) || Image.PreserveAspectCrop

      color: "transparent"

      Connections {
        target: LockService
        function onLock() {
          lockContent.forceActiveFocus();
        }
      }
      Loader {
        anchors.fill: parent
        active: lockSurface.hasScreen
        sourceComponent: Image {
          anchors.fill: parent
          fillMode: lockSurface.wallpaperFillMode
          layer.enabled: lockSurface.hasScreen
          layer.mipmap: false
          cache: true
          mipmap: false
          source: (lockSurface.wallpaperData && lockSurface.wallpaperData.wallpaper) ? lockSurface.wallpaperData.wallpaper : ((WallpaperService && WallpaperService.defaultWallpaper) ? WallpaperService.defaultWallpaper : "")
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
        onPressed: lockContent.forceActiveFocus()
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
        lockContext: LockService
        lockSurface: lockSurface
        theme: root.theme
      }
    }
  }
}
