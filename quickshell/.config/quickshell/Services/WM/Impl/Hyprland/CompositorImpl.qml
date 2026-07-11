pragma Singleton
import Quickshell
import Quickshell.Hyprland

Singleton {
  id: impl

  function exitSession(): void {
    Quickshell.execDetached(["uwsm", "stop"]);
  }

  function setDpms(powered: bool): void {
    Hyprland.dispatch(`hl.dsp.dpms({ action = "${powered ? "on" : "off"}" })`);
  }
}
