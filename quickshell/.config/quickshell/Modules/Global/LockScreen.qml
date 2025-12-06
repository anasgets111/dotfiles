pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Effects
import qs.Components
import qs.Services.Core
import qs.Services.WM

Scope {
  WlSessionLock {
    locked: LockService.locked

    WlSessionLockSurface {
      id: lockSurface

      readonly property bool isMainMonitor: MonitorService.activeMain === screen?.name
      readonly property var wallpaperData: screen && WallpaperService.wallpaperFor(screen.name)
      readonly property int wallpaperFillMode: WallpaperService.modeToFillMode(wallpaperData?.mode)
      readonly property url wallpaperSource: wallpaperData?.wallpaper ?? ""

      color: "transparent"

      FocusScope {
        anchors.fill: parent
        focus: true

        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: event => event.accepted = LockService.handleGlobalKeyPress(event)

        Image {
          anchors.fill: parent
          cache: false
          fillMode: lockSurface.wallpaperFillMode
          layer.enabled: !!lockSurface.wallpaperSource
          source: lockSurface.wallpaperSource

          layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blur: LockService.blurAmount
            blurEnabled: true
            blurMax: LockService.blurMax
            blurMultiplier: LockService.blurMultiplier
          }
        }

        LockContent {
          isMainMonitor: lockSurface.isMainMonitor
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
