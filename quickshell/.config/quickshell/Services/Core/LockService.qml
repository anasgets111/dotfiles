pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.Services.Core

Singleton {
  id: lockService

  property string authState: ""
  property bool authenticating: false
  readonly property real blurAmount: 0.9
  readonly property int blurMax: 64
  readonly property real blurMultiplier: 1
  readonly property int compactWidthThreshold: 440
  property bool locked: false
  property string passwordBuffer: ""
  // Computed status message for UI
  readonly property string statusMessage: {
    if (authenticating)
      return "Authenticating…";

    switch (authState) {
    case "error":
      return "Error";
    case "max":
      return "Too many tries";
    case "fail":
      return "Incorrect password";
    default:
      return "Enter password";
    }
  }
  readonly property var theme: ({
      "base": "#1e1e2e",
      "mantle": "#181825",
      "crust": "#11111b",
      "surface0": "#313244",
      "surface1": "#45475a",
      "surface2": "#585b70",
      "overlay0": "#6c7086",
      "overlay1": "#7f849c",
      "overlay2": "#9399b2",
      "subtext0": "#a6adc8",
      "subtext1": "#bac2de",
      "text": "#cdd6f4",
      "love": "#f38ba8",
      "mauve": "#cba6f7"
    })

  function handleGlobalKeyPress(event) {
    if (!locked)
      return false;

    if (IdleService.dpmsOffInSession)
      IdleService.wake();

    const key = event.key;
    if (key === Qt.Key_Enter || key === Qt.Key_Return) {
      if (!authenticating && passwordBuffer.length > 0)
        submitOrStart();

      return true;
    }
    if (key === Qt.Key_Backspace) {
      passwordBuffer = (event.modifiers & Qt.ControlModifier) ? "" : passwordBuffer.slice(0, -1);
      return true;
    }
    if (key === Qt.Key_Escape) {
      passwordBuffer = "";
      return true;
    }
    if (event.text && event.text.length === 1) {
      const code = event.text.charCodeAt(0);
      if (code >= 32 && code <= 126) {
        passwordBuffer += event.text;
        return true;
      }
    }
    return false;
  }

  function submitOrStart() {
    if (!authenticating && passwordBuffer.length > 0)
      pamContext.start();
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
        lockService.authState = result === PamResult.Error ? "error" : result === PamResult.MaxTries ? "max" : result === PamResult.Failed ? "fail" : "";
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

    onTriggered: lockService.authState = ""
  }
}
