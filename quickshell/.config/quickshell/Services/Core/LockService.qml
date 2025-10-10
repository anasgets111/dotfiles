pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.Services.Core

Singleton {
  id: lockService

  property string authState: ""
  property bool authenticating: false
  property bool locked: false
  property string passwordBuffer: ""

  function submitOrStart() {
    if (!authenticating && passwordBuffer.length > 0)
      pamContext.start();
  }
  function toggle() {
    locked = !locked;
  }

  function mapPamResultToState(result) {
    switch (result) {
    case PamResult.Error:
      return "error";
    case PamResult.MaxTries:
      return "max";
    case PamResult.Failed:
      return "fail";
    default:
      return "";
    }
  }

  function handleGlobalKeyPress(event) {
    // Only handle keyboard events when locked and not authenticating
    if (!locked || authenticating) {
      return false;
    }

    // Wake monitors on any keyboard input
    if (IdleService.dpmsOffInSession) {
      IdleService.wake();
    }

    const key = event.key;

    if (key === Qt.Key_Enter || key === Qt.Key_Return) {
      submitOrStart();
      return true;
    }

    if (key === Qt.Key_Backspace) {
      const next = (event.modifiers & Qt.ControlModifier) ? "" : passwordBuffer.slice(0, -1);
      passwordBuffer = next;
      return true;
    }

    if (key === Qt.Key_Escape) {
      passwordBuffer = "";
      return true;
    }

    if (event.text && event.text.length === 1) {
      const code = event.text.charCodeAt(0);
      if (code >= 0x20 && code <= 0x7E) {
        passwordBuffer = (passwordBuffer + event.text);
        return true;
      }
    }

    return false;
  }

  onLockedChanged: {
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
        lockService.authState = lockService.mapPamResultToState(result);
        if (lockService.authState)
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
