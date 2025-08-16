pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: lockService

    property bool ready: false
    property bool locked: false
    property bool prelockInProgress: false
    onPrelockInProgressChanged: {
        const now = new Date().toISOString();
        console.debug(`[LockService] prelockInProgress changed to: ${lockService.prelockInProgress} at ${now}`);
    }

    signal preLockRequested
    signal unlocked

    function requestLock() {
        const now = new Date().toISOString();
        console.debug(`[LockService] requestLock called. locked: ${locked} prelockInProgress: ${prelockInProgress} at ${now}`);
        if (locked || prelockInProgress) {
            console.debug(`[LockService] requestLock: Already locked or prelock in progress, aborting at ${now}.`);
            return;
        }
        prelockInProgress = true;
        console.debug(`[LockService] Pre-lock started at ${now}`);
        prelockTimeout.restart();
        preLockRequested();
        console.debug(`[LockService] preLockRequested signal emitted at ${now}`);
    }

    function requestUnlock() {
        const now = new Date().toISOString();
        if (!locked)
            return;
        locked = false;
        console.debug(`[LockService] Unlock requested at ${now}`);
        unlocked();
    }

    function confirmLock() {
        const now = new Date().toISOString();
        console.debug(`[LockService] confirmLock called. locked: ${locked} at ${now}`);
        if (locked) {
            console.debug(`[LockService] confirmLock: already locked, aborting at ${now}.`);
            return;
        }
        prelockInProgress = false;
        prelockTimeout.stop();
        locked = true;
        console.debug(`[LockService] Lock engaged at ${now}`);
    }
    IpcHandler {
        target: "session"

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
    // Give compositors a bit more time to deliver a frame
    property int prelockTimeoutMs: 200
    Timer {
        id: prelockTimeout
        interval: lockService.prelockTimeoutMs
        repeat: false
        onTriggered: {
            const now = new Date().toISOString();
            console.warn(`[LockService] Pre-lock timeout; proceeding with available screenshots at ${now}`);
            lockService.confirmLock();
        }
    }

    Component.onCompleted: {
        ready = true;
        console.debug("[LockService] Component.onCompleted. Screens:", Quickshell.screens);
        console.debug("[LockService] Ready");
    }
}
