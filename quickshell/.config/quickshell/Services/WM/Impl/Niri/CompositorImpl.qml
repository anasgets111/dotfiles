pragma Singleton
import Quickshell

Singleton {
  id: impl

  function exitSession(): void {
    Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]);
  }
  function setDpms(powered: bool): void {
    Quickshell.execDetached(["niri", "msg", "action", powered ? "power-on-monitors" : "power-off-monitors"]);
  }
}
