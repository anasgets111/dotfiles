pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services
import qs.Services.Core
import qs.Services.Utils
import qs.Services.SystemInfo
import qs.Config

Singleton {
  id: root

  readonly property bool autoInhibitorActive: MediaService.anyVideoPlaying || PrivacyService.cameraActive || PrivacyService.screenshareActive || PrivacyService.audioCaptureActive
  readonly property bool canLock: idleEnabled && settings.lockEnabled && !LockService.locked && (!settings.lockAfterDpms || !settings.dpmsEnabled || displaysPoweredOff)
  readonly property bool canPowerOffDisplays: idleEnabled && settings.dpmsEnabled && (settings.lockAfterDpms || LockService.locked || !settings.lockEnabled)
  readonly property bool canSuspend: idleEnabled && settings.suspendEnabled && displaysPoweredOff && (!settings.lockEnabled || LockService.locked)
  property bool displaysPoweredOff: false
  readonly property bool effectiveInhibited: fullscreenInhibitorActive || ((settings?.videoAutoInhibit ?? false) && autoInhibitorActive)
  readonly property bool fullscreenInhibitorActive: ToplevelManager.toplevels.values.some(toplevel => toplevel.fullscreen)
  readonly property bool idleEnabled: Settings.isLoaded && settings !== null && settings.enabled
  readonly property bool respectInhibitors: !LockService.locked && (settings?.respectInhibitors ?? true)
  readonly property var settings: Settings.data?.idleService ?? null
  property QsWindow window

  function setDisplaysPowered(powered: bool): void {
    const shouldBePoweredOff = !powered;
    if (root.displaysPoweredOff === shouldBePoweredOff)
      return;
    let command = null;
    if (MainService.currentWM === "hyprland")
      command = ["hyprctl", "dispatch", `hl.dsp.dpms({action="${powered ? "on" : "off"}"})`];
    else if (MainService.currentWM === "niri")
      command = ["niri", "msg", "action", powered ? "power-on-monitors" : "power-off-monitors"];
    if (!command) {
      Logger.warn("IdleService", `Unsupported WM for DPMS: ${MainService.currentWM}`);
      return;
    }
    root.displaysPoweredOff = shouldBePoweredOff;
    Quickshell.execDetached(command);
  }

  function wakeDisplays(): void {
    if (root.displaysPoweredOff)
      root.setDisplaysPowered(true);
  }

  IdleInhibitor {
    enabled: root.effectiveInhibited
    window: root.window
  }

  IdleMonitor {
    enabled: root.canLock
    respectInhibitors: root.respectInhibitors
    timeout: root.settings?.lockTimeoutSec ?? 0

    onIsIdleChanged: isIdle ? LockService.requestLock() : root.wakeDisplays()
  }

  IdleMonitor {
    enabled: root.canPowerOffDisplays
    respectInhibitors: root.respectInhibitors
    timeout: root.settings?.dpmsTimeoutSec ?? 0

    onIsIdleChanged: isIdle ? root.setDisplaysPowered(false) : root.wakeDisplays()
  }

  IdleMonitor {
    enabled: root.canSuspend
    respectInhibitors: root.respectInhibitors
    timeout: root.settings?.suspendTimeoutSec ?? 0

    onIsIdleChanged: isIdle ? PowerManagementService.suspend() : root.wakeDisplays()
  }

  Connections {
    function onLockedChanged(): void {
      if (!LockService.locked)
        root.wakeDisplays();
    }

    target: LockService
  }
}
