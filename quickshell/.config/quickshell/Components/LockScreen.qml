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

      readonly property string screenName: screen?.name || ""
      readonly property bool hasScreen: !!screen
      readonly property bool isMainMonitor: hasScreen && MonitorService?.activeMain === screenName
      readonly property var wallpaperData: hasScreen && screenName ? WallpaperService.wallpaperFor(screenName) : null
      readonly property int wallpaperFillMode: WallpaperService.modeToFillMode(wallpaperData?.mode)

      color: "transparent"

      FocusScope {
        anchors.fill: parent
        focus: true

        // Global keyboard event handler - always active when lock screen is visible
        Keys.onPressed: event => {
          if (LockService.handleGlobalKeyPress(event)) {
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
            layer.enabled: LockService.locked
            cache: false
            mipmap: false
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
