pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import qs.Services.Core as Core
import qs.Components as Components

WlSessionLock {
    id: wlLock
    locked: Core.LockService.locked

    surface: Components.LockSurface {
        lock: wlLock
    }
}
