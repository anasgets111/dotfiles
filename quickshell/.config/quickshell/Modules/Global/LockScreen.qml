pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Services.Core
import qs.Services.WM

Scope {
  WlSessionLock {
    locked: LockService.locked

    WlSessionLockSurface {
      id: lockSurface

      readonly property string currentPath: screen?.name ? WallpaperService.wallpaperPath(screen.name) : ""
      readonly property bool isMainMonitor: MonitorService.activeMain === screen?.name

      color: "transparent"

      FocusScope {
        id: stage

        readonly property real backgroundOpacity: Math.max(0, Math.min(1, phase))
        readonly property real contentOpacity: Math.max(0, Math.min(1, phase - 1))
        property real phase: 0

        anchors.fill: parent
        focus: true

        Component.onCompleted: {
          forceActiveFocus();
          if (LockService.unlocking) {
            phase = 2;
            unlockAnimation.restart();
          } else {
            phase = 0;
            lockInAnimation.restart();
          }
        }
        Keys.onPressed: event => event.accepted = LockService.handleGlobalKeyPress(event)

        Connections {
          function onUnlockingChanged() {
            if (LockService.unlocking) {
              unlockAnimation.restart();
              return;
            }
            if (LockService.locked)
              lockInAnimation.restart();
          }

          target: LockService
        }
        SequentialAnimation {
          id: lockInAnimation

          alwaysRunToEnd: true

          ScriptAction {
            script: unlockAnimation.stop()
          }
          NumberAnimation {
            duration: Theme.animationSlow
            easing.type: Easing.OutCubic
            property: "phase"
            target: stage
            to: 1
          }
          NumberAnimation {
            duration: Theme.animationSlow
            easing.type: Easing.OutCubic
            property: "phase"
            target: stage
            to: 2
          }
        }
        SequentialAnimation {
          id: unlockAnimation

          alwaysRunToEnd: true

          ScriptAction {
            script: lockInAnimation.stop()
          }
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InCubic
            property: "phase"
            target: stage
            to: 1
          }
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InCubic
            property: "phase"
            target: stage
            to: 0
          }
          ScriptAction {
            script: {
              if ((lockSurface.isMainMonitor || lockSurface.screen?.name === Quickshell.screens[0]?.name) && LockService.unlocking)
                LockService.finalizeUnlock();
            }
          }
        }
        Image {
          id: lockWallpaper

          anchors.fill: parent
          cache: false
          fillMode: WallpaperService.modeToFillMode(WallpaperService.wallpaperMode(lockSurface.screen?.name ?? ""))
          source: lockSurface.currentPath
          sourceSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))
          visible: false
        }
        MultiEffect {
          anchors.fill: parent
          autoPaddingEnabled: false
          blur: Settings.data.lockBlurAmount * stage.backgroundOpacity
          blurEnabled: !!lockSurface.currentPath && stage.backgroundOpacity > 0
          blurMax: Settings.data.lockBlurMax
          blurMultiplier: Settings.data.lockBlurMultiplier
          opacity: stage.backgroundOpacity
          source: lockWallpaper
        }
        Loader {
          active: !IdleService.displaysPoweredOff
          anchors.fill: parent
          opacity: stage.contentOpacity
          scale: Theme.lockClosedScale + ((1 - Theme.lockClosedScale) * stage.contentOpacity)

          sourceComponent: Item {
            LockContent {
              isMainMonitor: lockSurface.isMainMonitor
            }
          }
        }
      }
    }
  }
}
