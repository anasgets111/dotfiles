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

    // Expose IPC: `quickshell ipc call lock lock` | unlock | toggle | status | islocked
    IpcHandler {
        target: "lock"

        function lock(): string {
            Logger.log("LockService:IPC", "lock");
            lockService.locked = true;
            return "locked";
        }

        function unlock(): string {
            Logger.log("LockService:IPC", "unlock");
            lockService.locked = false;
            return "unlocked";
        }

        function toggle(): string {
            Logger.log("LockService:IPC", "toggle");
            lockService.toggle();
            return lockService.locked ? "locked" : "unlocked";
        }

        function status(): string {
            const s = lockService.locked ? "locked" : "unlocked";
            Logger.log("LockService:IPC", `status -> ${s}`);
            return s;
        }

        function islocked(): string {
            Logger.log("LockService:IPC", `islocked -> ${lockService.locked}`);
            return lockService.locked ? "true" : "false";
        }
    }
}
