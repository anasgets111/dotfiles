pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.Services.Core
import qs.Services.WM

Singleton {
  id: root

  property bool authenticating: false
  // TODO: move to config/theme
  readonly property real blurAmount: 0.9
  readonly property int blurMax: 64
  readonly property real blurMultiplier: 1
  readonly property bool hasAuthFailure: pamResult !== PamResult.Success
  property int layoutBeforeLockIndex: -1
  property bool locked: false
  property int pamResult: PamResult.Success
  property string passwordBuffer: ""
  readonly property bool passwordRejected: pamResult === PamResult.Failed
  property bool unlocking: false

  function finalizeUnlock(): void {
    if (unlocking)
      locked = false;
  }

  function handleGlobalKeyPress(event: var): bool {
    if (!locked || authenticating || unlocking)
      return false;
    if (IdleService.displaysPoweredOff)
      IdleService.wakeDisplays();
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
    if (!text)
      return false;
    const code = text.charCodeAt(0);
    if (code >= 32 && code !== 127) {
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
    if (locked)
      unlocking = true;
  }

  onLockedChanged: {
    unlocking = false;

    if (locked) {
      layoutBeforeLockIndex = KeyboardLayoutService.currentLayoutIndex;
      KeyboardLayoutService.setLayoutByIndex(0);
      return;
    }

    passwordBuffer = "";
    pamResult = PamResult.Success;
    KeyboardLayoutService.setLayoutByIndex(layoutBeforeLockIndex);
    layoutBeforeLockIndex = -1;
  }

  PamContext {
    id: pamContext

    onActiveChanged: root.authenticating = active
    onCompleted: result => {
      if (result === PamResult.Success) {
        root.requestUnlock();
      } else {
        root.pamResult = PamResult.Success;
        root.pamResult = result;
        if (root.hasAuthFailure)
          pamResultResetTimer.restart();
      }
    }
    onResponseRequiredChanged: {
      if (responseRequired) {
        respond(root.passwordBuffer);
        root.passwordBuffer = "";
      }
    }
  }

  Timer {
    id: pamResultResetTimer

    interval: 1000

    onTriggered: root.pamResult = PamResult.Success
  }
}
