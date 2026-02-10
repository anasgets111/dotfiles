pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.Services.Core
import qs.Services.WM

Singleton {
  id: lockService

  property string authState: ""
  readonly property var authStates: ({
      idle: "",
      error: "error",
      max: "max",
      fail: "fail"
    })
  property bool authenticating: false
  readonly property real blurAmount: 0.9
  readonly property int blurMax: 64
  readonly property real blurMultiplier: 1
  property bool locked: false
  property string passwordBuffer: ""
  property string savedLayout: ""
  readonly property string statusMessage: authenticating ? "Authenticating…" : (statusMessages[authState] ?? "Enter password")
  readonly property var statusMessages: ({
      error: "Error",
      max: "Too many tries",
      fail: "Incorrect password"
    })

  function handleGlobalKeyPress(event) {
    if (!locked || authenticating)
      return false;
    if (IdleService.dpmsOff)
      IdleService.wake();
    switch (event.key) {
    case Qt.Key_Enter:
    case Qt.Key_Return:
      if (!authenticating && passwordBuffer)
        pamContext.start();
      return true;
    case Qt.Key_Backspace:
      passwordBuffer = (event.modifiers & Qt.ControlModifier) ? "" : passwordBuffer.slice(0, -1);
      return true;
    case Qt.Key_Escape:
      passwordBuffer = "";
      return true;
    }
    const text = event.text;
    if (!text)
      return false;
    const code = text.charCodeAt(0);
    if (code >= 32 && code <= 126) {
      passwordBuffer += text;
      return true;
    }
    return false;
  }

  onLockedChanged: {
    if (locked) {
      if (KeyboardLayoutService.layouts.length > 0) {
        lockService.savedLayout = KeyboardLayoutService.currentLayout;
        KeyboardLayoutService.cycleLayout(KeyboardLayoutService.layouts[0]);
      }
    } else {
      passwordBuffer = "";
      authState = authStates.idle;
      if (lockService.savedLayout) {
        KeyboardLayoutService.cycleLayout(lockService.savedLayout);
        lockService.savedLayout = "";
      }
    }
  }

  PamContext {
    id: pamContext

    onActiveChanged: lockService.authenticating = active
    onCompleted: result => {
      if (result === PamResult.Success) {
        lockService.locked = false;
      } else {
        lockService.authState = ({
            [PamResult.Error]: lockService.authStates.error,
            [PamResult.MaxTries]: lockService.authStates.max,
            [PamResult.Failed]: lockService.authStates.fail
          })[result] ?? lockService.authStates.idle;
        if (lockService.authState)
          authStateResetTimer.restart();
      }
    }
    onResponseRequiredChanged: {
      if (responseRequired) {
        respond(lockService.passwordBuffer);
        lockService.passwordBuffer = "";
      }
    }
  }

  Timer {
    id: authStateResetTimer

    interval: 1000

    onTriggered: lockService.authState = lockService.authStates.idle
  }
}
