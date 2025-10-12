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

      readonly property bool hasScreen: !!screen
      readonly property bool isMainMonitor: hasScreen && MonitorService?.activeMain === screenName
      readonly property string screenName: screen?.name || ""
      readonly property var wallpaperData: hasScreen && screenName ? WallpaperService.wallpaperFor(screenName) : null
      readonly property int wallpaperFillMode: WallpaperService.modeToFillMode(wallpaperData?.mode)

      color: "transparent"

      FocusScope {
        anchors.fill: parent
        focus: true

        Component.onCompleted: {
          forceActiveFocus();
        }

        // Global keyboard event handler - always active when lock screen is visible
        Keys.onPressed: event => {
          if (LockService.handleGlobalKeyPress(event)) {
            event.accepted = true;
          }
        }

        Item {
          anchors.fill: parent

          Image {
            id: wallpaperImage

            anchors.fill: parent
            cache: false
            fillMode: lockSurface.wallpaperFillMode
            layer.effect: LockService.locked ? multiEffectComponent : null
            layer.enabled: LockService.locked && source !== ""
            source: LockService.locked ? (lockSurface.wallpaperData?.wallpaper || "") : ""
          }

          Component {
            id: multiEffectComponent

            MultiEffect {
              autoPaddingEnabled: false
              blur: LockService.blurAmount
              blurEnabled: true
              blurMax: LockService.blurMax
              blurMultiplier: LockService.blurMultiplier
            }
          }

          LockContent {
            id: lockContent

            lockContext: LockService
            lockSurface: lockSurface
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
