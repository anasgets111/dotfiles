pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Effects
import qs.Services.Core
import qs.Services.WM

Scope {
  id: root

  WlSessionLock {
    id: sessionLock

    locked: LockService.locked

    WlSessionLockSurface {
      id: lockSurface

      readonly property bool isMainMonitor: MonitorService.activeMain === screen?.name
      readonly property var wallpaperData: screen ? WallpaperService.wallpaperFor(screen.name) : null

      color: "transparent"

      FocusScope {
        anchors.fill: parent
        focus: true

        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: event => {
          if (LockService.handleGlobalKeyPress(event))
            event.accepted = true;
        }

        Image {
          anchors.fill: parent
          cache: false
          fillMode: WallpaperService.modeToFillMode(lockSurface.wallpaperData?.mode)
          layer.enabled: source !== ""
          source: lockSurface.wallpaperData?.wallpaper || ""

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
