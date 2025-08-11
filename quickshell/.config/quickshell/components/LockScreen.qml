pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland
import "../services" as Services

WlSessionLock {
    id: wlLock
    locked: Services.LockService.locked
    property bool unlocked: !locked

    Component.onCompleted: Services.LockService.registerSessionLock(wlLock)
    Component.onDestruction: Services.LockService.unregisterSessionLock()

    // One LockSurface — Quickshell duplicates it for each monitor
    LockSurface {
        lock: wlLock
    }
}
