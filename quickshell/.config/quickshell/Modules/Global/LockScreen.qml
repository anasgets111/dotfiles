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

      readonly property string currentPath: screen?.name ? WallpaperService.wallpaperPath(screen.name) : ""
      readonly property bool isMainMonitor: MonitorService.activeMain === screen?.name
      readonly property url wallpaperSource: currentPath ? `file://${currentPath}` : ""

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
            duration: 220
            easing.type: Easing.OutCubic
            property: "phase"
            target: stage
            to: 1
          }

          NumberAnimation {
            duration: 220
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
            duration: 180
            easing.type: Easing.InCubic
            property: "phase"
            target: stage
            to: 1
          }

          NumberAnimation {
            duration: 180
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
          anchors.fill: parent
          cache: false
          fillMode: WallpaperService.modeToFillMode(lockSurface.screen?.name ? WallpaperService.wallpaperMode(lockSurface.screen.name) : "fill")
          layer.enabled: !!lockSurface.wallpaperSource
          opacity: stage.backgroundOpacity
          source: lockSurface.wallpaperSource

          layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blur: LockService.blurAmount * stage.backgroundOpacity
            blurEnabled: stage.backgroundOpacity > 0
            blurMax: LockService.blurMax
            blurMultiplier: LockService.blurMultiplier
          }
        }

        LockContent {
          isMainMonitor: lockSurface.isMainMonitor
          opacity: stage.contentOpacity
          scale: 0.96 + (0.04 * stage.contentOpacity)
        }
      }
    }
  }
}
