pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Singleton {
    id: lockService

    // Lifecycle
    property bool ready: false

    // Lock state
    property bool locked: false
    readonly property bool unlocked: !locked

    // Reference to WlSessionLock (set by UI)
    property var sessionLock: null

    // === Actions ===
    function requestLock() {
        if (locked) {
            console.log("[LockService] Already locked");
            return;
        }
        locked = true;
        console.log("[LockService] Lock requested");
    }

    function requestUnlock() {
        if (!locked) {
            console.log("[LockService] Already unlocked");
            return;
        }
        locked = false;
        console.log("[LockService] Unlock requested");
    }

    // Called by UI when WlSessionLock is created
    function registerSessionLock(lockObj) {
        sessionLock = lockObj;
        console.log("[LockService] Session lock registered");
    }

    // Called by UI when WlSessionLock is destroyed
    function unregisterSessionLock() {
        sessionLock = null;
        console.log("[LockService] Session lock unregistered");
    }

    // === IPC interface ===
    IpcHandler {
        target: "lock"

        function lock() {
            lockService.requestLock();
        }

        function unlock() {
            lockService.requestUnlock();
        }

        function isLocked() {
            return lockService.locked;
        }
    }

    // === Keyboard shortcuts ===
    // Lock shortcut
    Shortcut {
        sequence: "Meta+L"
        onActivated: lockService.requestLock()
    }

    // Unlock shortcut
    Shortcut {
        sequence: "Meta+U"
        onActivated: lockService.requestUnlock()
    }

    Component.onCompleted: {
        ready = true;
        console.log("[LockService] Ready");
    }
}
