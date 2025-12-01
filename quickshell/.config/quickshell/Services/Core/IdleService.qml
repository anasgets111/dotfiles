pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services
import qs.Services.Core
import qs.Services.Utils
import qs.Config

Singleton {
  id: root

  property bool dpmsOff: false
  readonly property int dpmsTimeout: lockTimeout + (ready && settings.dpmsEnabled ? settings.dpmsTimeoutSec : 0)
  readonly property bool effectiveInhibited: !!settings?.videoAutoInhibit && MediaService.anyVideoPlaying
  readonly property int lockTimeout: ready && !LockService.locked && settings.lockEnabled ? settings.lockTimeoutSec : 0
  readonly property bool monitorsActive: ready && rearmToken && !!settings.enabled
  readonly property bool ready: Settings.isLoaded && !!settings
  property bool rearmToken: true
  readonly property bool respectInhibitors: !LockService.locked && (settings?.respectInhibitors ?? true)
  readonly property var settings: Settings.data?.idleService
  readonly property int suspendTimeout: dpmsTimeout + (ready && settings.suspendEnabled ? settings.suspendTimeoutSec : 0)
  property QsWindow window

  function dpmsCmd(on: bool): list<string> {
    const wm = MainService.currentWM;
    const cmds = {
      hyprland: on ? ["hyprctl", "dispatch", "dpms", "on"] : ["hyprctl", "dispatch", "dpms", "off"],
      niri: on ? ["niri", "msg", "action", "power-on-monitors"] : ["niri", "msg", "action", "power-off-monitors"]
    };
    return cmds[wm] || [];
  }

  function setDpms(on: bool): void {
    if (root.dpmsOff === !on)
      return;
    root.dpmsOff = !on;
    const cmd = root.dpmsCmd(on);
    if (cmd.length)
      Quickshell.execDetached(cmd);
    else
      Logger.warn("IdleService", `Unsupported WM for DPMS: ${MainService.currentWM}`);
  }

  function suspend(): void {
    Quickshell.execDetached(["systemctl", "suspend"]);
  }

  function wake(): void {
    if (root.dpmsOff)
      root.setDpms(true);
  }

  onSuspendTimeoutChanged: {
    root.rearmToken = false;
    Qt.callLater(() => root.rearmToken = true);
  }

  IdleInhibitor {
    enabled: root.effectiveInhibited
    window: root.window
  }

  IdleMonitor {
    enabled: root.monitorsActive && root.settings.lockEnabled && !LockService.locked
    respectInhibitors: root.respectInhibitors
    timeout: root.lockTimeout

    onIsIdleChanged: isIdle ? LockService.locked = true : root.wake()
  }

  IdleMonitor {
    enabled: root.monitorsActive && root.settings.dpmsEnabled
    respectInhibitors: root.respectInhibitors
    timeout: root.dpmsTimeout

    onIsIdleChanged: isIdle ? root.setDpms(false) : root.wake()
  }

  IdleMonitor {
    enabled: root.monitorsActive && root.settings.suspendEnabled
    respectInhibitors: root.respectInhibitors
    timeout: root.suspendTimeout

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
