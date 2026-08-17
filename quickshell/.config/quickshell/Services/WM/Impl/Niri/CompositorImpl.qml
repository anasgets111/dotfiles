pragma Singleton
import Quickshell

Singleton {
  function exitSession(): void {
    Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]);
  }
  function launchApp(desktopId: string): void {
    Quickshell.execDetached(["niri", "msg", "action", "spawn", "--", "gtk-launch", desktopId]);
  }
  function setDpms(powered: bool): void {
    Quickshell.execDetached(["niri", "msg", "action", powered ? "power-on-monitors" : "power-off-monitors"]);
  }
}
