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

  readonly property var dpmsCmds: ({
      hyprland: {
        on: ["hyprctl", "dispatch", "dpms", "on"],
        off: ["hyprctl", "dispatch", "dpms", "off"]
      },
      niri: {
        on: ["niri", "msg", "action", "power-on-monitors"],
        off: ["niri", "msg", "action", "power-off-monitors"]
      }
    })
  property bool dpmsOff: false
  readonly property bool effectiveInhibited: (!!settings?.videoAutoInhibit && (MediaService.anyVideoPlaying || PrivacyService.cameraActive || PrivacyService.screenshareActive))
  readonly property bool ready: Settings.isLoaded && !!settings
  readonly property bool respectInhibitors: !LockService.locked && (settings?.respectInhibitors ?? true)
  readonly property var settings: Settings.data?.idleService
  property QsWindow window

  function setDpms(on: bool): void {
    if (root.dpmsOff === !on)
      return;
    root.dpmsOff = !on;
    const cmd = root.dpmsCmds[MainService.currentWM]?.[on ? "on" : "off"];
    if (cmd)
      Quickshell.execDetached(cmd);
    else
      Logger.warn("IdleService", `Unsupported WM for DPMS: ${MainService.currentWM}`);
  }

  function suspend(): void {
    PowerManagementService.suspend();
  }

  function wake(): void {
    if (root.dpmsOff)
      root.setDpms(true);
  }

  IdleInhibitor {
    enabled: root.effectiveInhibited
    window: root.window
  }

  IdleMonitor {
    enabled: root.ready && !!root.settings.enabled && root.settings.lockEnabled && !LockService.locked
    respectInhibitors: root.respectInhibitors
    timeout: root.settings?.lockTimeoutSec ?? 0

    onIsIdleChanged: isIdle ? LockService.requestLock() : root.wake()
  }

  IdleMonitor {
    enabled: root.ready && !!root.settings.enabled && root.settings.dpmsEnabled && (LockService.locked || !root.settings.lockEnabled)
    respectInhibitors: root.respectInhibitors
    timeout: root.settings?.dpmsTimeoutSec ?? 0

    onIsIdleChanged: isIdle ? root.setDpms(false) : root.wake()
  }

  IdleMonitor {
    enabled: root.ready && !!root.settings.enabled && root.settings.suspendEnabled && root.dpmsOff
    respectInhibitors: root.respectInhibitors
    timeout: root.settings?.suspendTimeoutSec ?? 0

    onIsIdleChanged: isIdle ? root.suspend() : root.wake()
  }

  Connections {
    function onLockedChanged(): void {
      if (!LockService.locked)
        root.wake();
    }

    target: LockService
  }
}
