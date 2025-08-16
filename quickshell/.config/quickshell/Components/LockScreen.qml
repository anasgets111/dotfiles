pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import qs.Services as Services
import qs.Components as Components

WlSessionLock {
    id: wlLock
    locked: Services.LockService.locked

    surface: Components.LockSurface {
        lock: wlLock
    }
}
