import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.Services.Utils
pragma Singleton

Singleton {
    id: lockService

    property string authState: "" // "", "error", "max", "fail"
    property bool authenticating: false
    property bool locked: false
    property string passwordBuffer: ""

    signal lock()
    signal unlock()

    function cancelAuth() {
        authenticating = false;
    }

    function clearInput() {
        passwordBuffer = "";
    }

    function submitOrStart() {
        Logger.log("LockService", `submitOrStart called; bufLen=${passwordBuffer.length}, authenticating=${authenticating}`);
        if (authenticating)
            return ;

        if (passwordBuffer.length === 0)
            return ;

        pamContext.start();
    }

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
        onCompleted: (result) => {
            lockService.authenticating = false;
            if (result === PamResult.Success) {
                lockService.passwordBuffer = "";
                lockService.locked = false;
                return ;
            }
            if (result === PamResult.Error)
                lockService.authState = "error";
            else if (result === PamResult.MaxTries)
                lockService.authState = "max";
            else if (result === PamResult.Failed)
                lockService.authState = "fail";
            authStateResetTimer.restart();
        }
        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(lockService.passwordBuffer);
                lockService.passwordBuffer = "";
                Logger.log("LockService", "PAM response sent; buffer cleared");
            }
        }
    }

    Timer {
        id: authStateResetTimer

        interval: 1000
        onTriggered: lockService.authState = ""
    }

}
