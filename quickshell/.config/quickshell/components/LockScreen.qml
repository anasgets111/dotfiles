pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import "../services" as Services
import "." as Components

WlSessionLock {
    id: wlLock
    locked: Services.LockService.locked

    surface: Components.LockSurface {
        lock: wlLock
    }
}
