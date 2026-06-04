pragma Singleton
import Quickshell

Singleton {
  id: impl

  function exitSession(): void {
    Quickshell.execDetached(["uwsm", "stop"]);
  }

  function setDpms(powered: bool): void {
    Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.dpms({action="${powered ? "on" : "off"}"})`]);
  }
}
