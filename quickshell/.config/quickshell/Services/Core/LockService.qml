pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.SystemInfo

// Minimal lock service to toggle session lock from anywhere
Singleton {
    id: lockService

    // Public API
    property bool locked: false
    property var logger: LoggerService

    signal lock
    signal unlock

    function toggle() {
        logger.log("LockService", `toggle requested; current=${locked}`);
        locked = !locked;
    }

    Component.onCompleted: {
        logger.log("LockService", `ready; initial locked=${locked}`);
    }

    onLockedChanged: {
        logger.log("LockService", `locked changed -> ${locked}`);
        if (locked)
            lock();
        else
            unlock();
    }

    // Expose IPC: `quickshell ipc call lock lock` | unlock | toggle | status | islocked
    IpcHandler {
        target: "lock"

        function lock(): string {
            lockService.logger.log("LockService:IPC", "lock");
            lockService.locked = true;
            return "locked";
        }

        function unlock(): string {
            lockService.logger.log("LockService:IPC", "unlock");
            lockService.locked = false;
            return "unlocked";
        }

        function toggle(): string {
            lockService.logger.log("LockService:IPC", "toggle");
            lockService.toggle();
            return lockService.locked ? "locked" : "unlocked";
        }

        function status(): string {
            const s = lockService.locked ? "locked" : "unlocked";
            lockService.logger.log("LockService:IPC", `status -> ${s}`);
            return s;
        }

        function islocked(): string {
            lockService.logger.log("LockService:IPC", `islocked -> ${lockService.locked}`);
            return lockService.locked ? "true" : "false";
        }
    }
}
