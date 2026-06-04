pragma Singleton
import Quickshell
import qs.Services
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: service

  readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.CompositorImpl : MainService.currentWM === "niri" ? Niri.CompositorImpl : null

  function exitSession(): void {
    backend?.exitSession?.();
  }

  function setDisplaysPowered(powered: bool): bool {
    if (!backend?.setDpms)
      return false;
    backend.setDpms(powered);
    return true;
  }
}
