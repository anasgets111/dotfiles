pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam

Singleton {
  id: lockService

  property string authState: ""            // "", "error", "max", "fail"
  property bool authenticating: false
  property bool locked: false
  property string passwordBuffer: ""

  signal lock
  signal unlock

  function cancelAuth() {
    authenticating = false;
  }
  function clearInput() {
    passwordBuffer = "";
  }
  function submitOrStart() {
    if (!authenticating && passwordBuffer.length > 0)
      pamContext.start();
  }
  function toggle() {
    locked = !locked;
  }

  onLockedChanged: {
    locked ? lock() : unlock();
    if (!locked) {
      passwordBuffer = "";
      authState = "";
      authenticating = false;
    }
  }

  PamContext {
    id: pamContext

    onActiveChanged: lockService.authenticating = active
    onCompleted: result => {
      lockService.authenticating = false;
      if (result === PamResult.Success) {
        lockService.passwordBuffer = "";
        lockService.locked = false;
      } else {
        lockService.authState = result === PamResult.Error ? "error" : result === PamResult.MaxTries ? "max" : result === PamResult.Failed ? "fail" : "";
        authStateResetTimer.restart();
      }
    }
    onResponseRequiredChanged: if (responseRequired) {
      respond(lockService.passwordBuffer);
      lockService.passwordBuffer = "";
    }
  }

  Timer {
    id: authStateResetTimer
    interval: 1000
    onTriggered: lockService.authState = ""
  }
}
