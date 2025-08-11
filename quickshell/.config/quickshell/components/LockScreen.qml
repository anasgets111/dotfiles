pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import QtQuick.Effects
import "../services" as Services

WlSessionLock {
    id: wlLock
    locked: Services.LockService.locked

    // Register with the service so it can control the lock
    Component.onCompleted: Services.LockService.registerSessionLock(wlLock)
    Component.onDestruction: Services.LockService.unregisterSessionLock()

    WlSessionLockSurface {
        id: surface
        required property WlSessionLock lock
        lock: wlLock

        color: "transparent"

        // Background blur
        ScreencopyView {
            anchors.fill: parent
            captureSource: surface.screen
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: Services.LockService.locked ? 1 : 0
                blurMax: 64
                blurMultiplier: 1
                Behavior on blur {
                    NumberAnimation {
                        duration: 300
                    }
                }
            }
        }

        // Centered lock input
        LockInput {
            anchors.centerIn: parent
            lock: surface
        }
    }
}
