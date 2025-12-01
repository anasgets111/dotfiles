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
  property bool locked: false
  property string passwordBuffer: ""
  readonly property string statusMessage: authenticating ? "Authenticating…" : ({
      error: "Error",
      max: "Too many tries",
      fail: "Incorrect password"
    }[authState] ?? "Enter password")
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
    if (event.text) {
      const code = event.text.charCodeAt(0);
      if (code >= 32 && code <= 126) {
        passwordBuffer += event.text;
        return true;
      }
    }
    return false;
  }

  onLockedChanged: {
    if (!locked) {
      passwordBuffer = "";
      authState = "";
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
            [PamResult.Error]: "error",
            [PamResult.MaxTries]: "max",
            [PamResult.Failed]: "fail"
          })[result] ?? "";
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
