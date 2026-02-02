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
      readonly property string currentPath: screen?.name ? WallpaperService.wallpaperPath(screen.name) : ""
      readonly property string currentMode: screen?.name ? WallpaperService.wallpaperMode(screen.name) : "fill"
      readonly property int wallpaperFillMode: WallpaperService.modeToFillMode(currentMode)
      readonly property url wallpaperSource: currentPath ? `file://${currentPath}` : ""

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

        // one day :D
        // ScreencopyView {
        //   id: background

        //   anchors.fill: parent
        //   captureSource: lockSurface.screen
        //   layer.enabled: true

        //   layer.effect: MultiEffect {
        //     autoPaddingEnabled: false
        //     blur: 0.9
        //     blurEnabled: true
        //     blurMax: 64
        //     blurMultiplier: 1
        //   }
        // }

        LockContent {
          isMainMonitor: lockSurface.isMainMonitor
        }
      }
    }
  }
}
