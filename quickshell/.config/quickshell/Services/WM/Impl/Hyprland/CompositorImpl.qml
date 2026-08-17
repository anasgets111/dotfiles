pragma Singleton
import Quickshell
import Quickshell.Hyprland

Singleton {
  function exitSession(): void {
    Quickshell.execDetached(["uwsm", "stop"]);
  }
  function launchApp(desktopId: string): void {
    Quickshell.execDetached(["uwsm", "app", "--", `${desktopId.replace(/\.desktop$/, "")}.desktop`]);
  }
  function setDpms(powered: bool): void {
    Hyprland.dispatch(`hl.dsp.dpms({ action = "${powered ? "on" : "off"}" })`);
  }
}
