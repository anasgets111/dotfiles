pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils

// Minimal lock service to toggle session lock from anywhere
Singleton {
    id: lockService

    // Public API
    property bool locked: false

    signal lock
    signal unlock

    function toggle() {
        Logger.log("LockService", `toggle requested; current=${locked}`);
        locked = !locked;
    }

    Component.onCompleted: {
        Logger.log("LockService", `ready; initial locked=${locked}`);
    }

    onLockedChanged: {
        Logger.log("LockService", `locked changed -> ${locked}`);
        if (locked)
            lock();
        else
            unlock();
    }
}
