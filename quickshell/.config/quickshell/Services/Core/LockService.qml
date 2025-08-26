pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.Services.Utils

Singleton {
    id: lockService

    property bool locked: false
    property string passwordBuffer: ""
    property string authState: ""     // "", "error", "max", "fail"
    property bool authenticating: false

    function submitOrStart() {
        Logger.log("LockService", `submitOrStart called; bufLen=${passwordBuffer.length}, authenticating=${authenticating}`);
        if (authenticating)
            return;
        if (passwordBuffer.length === 0)
            return;
        pamContext.start();
    }
    function clearInput() {
        passwordBuffer = "";
    }
    function cancelAuth() {
        authenticating = false;
    }

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

        if (!locked) {
            passwordBuffer = "";
            authState = "";
            authenticating = false;
        }
    }

    PamContext {
        id: pamContext
        onActiveChanged: lockService.authenticating = active
        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(lockService.passwordBuffer);
                lockService.passwordBuffer = "";
                Logger.log("LockService", "PAM response sent; buffer cleared");
            }
        }
        onCompleted: result => {
            lockService.authenticating = false;
            if (result === PamResult.Success) {
                lockService.passwordBuffer = "";
                lockService.locked = false;
                return;
            }
            if (result === PamResult.Error)
                lockService.authState = "error";
            else if (result === PamResult.MaxTries)
                lockService.authState = "max";
            else if (result === PamResult.Failed)
                lockService.authState = "fail";
            authStateResetTimer.restart();
        }
    }

    Timer {
        id: authStateResetTimer
        interval: 1000
        onTriggered: lockService.authState = ""
    }
}
