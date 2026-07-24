pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.Services.WM

Singleton {
  id: root

  property int _layoutBeforeLockIndex: -1
  readonly property bool authenticating: pamContext.active
  property bool locked: false
  property string passwordBuffer: ""
  readonly property bool passwordRejected: rejectionTimer.running
  property bool unlocking: false

  signal authFailed

  function finalizeUnlock(): void {
    if (unlocking)
      locked = false;
  }
  function handleGlobalKeyPress(event: var): bool {
    if (!locked || authenticating || unlocking)
      return false;
    switch (event.key) {
    case Qt.Key_Enter:
    case Qt.Key_Return:
      if (passwordBuffer)
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
    if (text && text.charCodeAt(0) >= 32 && text.charCodeAt(0) !== 127) {
      passwordBuffer += text;
      return true;
    }
    return false;
  }
  function requestLock(): void {
    unlocking = false;
    locked = true;
  }
  function requestUnlock(): void {
    unlocking = locked;
  }

  onLockedChanged: {
    unlocking = false;
    if (locked)
      _layoutBeforeLockIndex = KeyboardLayoutService.currentLayoutIndex;
    else {
      passwordBuffer = "";
      rejectionTimer.stop();
    }
    KeyboardLayoutService.setLayoutByIndex(locked ? 0 : _layoutBeforeLockIndex);
  }

  PamContext {
    id: pamContext

    onCompleted: result => {
      if (result === PamResult.Success) {
        root.requestUnlock();
        return;
      }
      if (result === PamResult.Failed)
        rejectionTimer.restart();
      else
        rejectionTimer.stop();
      root.authFailed();
    }
    onResponseRequiredChanged: {
      if (!responseRequired)
        return;
      respond(root.passwordBuffer);
      root.passwordBuffer = "";
    }
  }
  Timer {
    id: rejectionTimer

    interval: 1000
  }
}
