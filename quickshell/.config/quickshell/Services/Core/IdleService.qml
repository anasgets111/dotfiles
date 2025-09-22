pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.Core
import qs.Services.Utils
import qs.Services
import qs.Config

Singleton {
  id: idleDaemon

  property var window
  readonly property var settings: Settings.data.idleService
  property bool dpmsOffInSession: false
  readonly property bool monitorsEnabled: Settings.isLoaded && settings.enabled && (settings.lockEnabled || settings.dpmsEnabled || settings.suspendEnabled)
  readonly property bool baseEnabled: rearmToken && monitorsEnabled
  readonly property bool monitorRespectInhibitors: settings.respectInhibitors && !LockService.locked
  readonly property bool effectiveInhibited: settings.videoAutoInhibit && MediaService.anyVideoPlaying
  readonly property int lockStageTimeoutSec: (!LockService.locked && settings.lockEnabled) ? settings.lockTimeoutSec : 0
  readonly property int dpmsStageTimeoutSec: settings.dpmsEnabled ? (lockStageTimeoutSec + settings.dpmsTimeoutSec) : lockStageTimeoutSec
  readonly property int suspendStageTimeoutSec: settings.suspendEnabled ? (dpmsStageTimeoutSec + settings.suspendTimeoutSec) : dpmsStageTimeoutSec
  readonly property int totalTimeout: suspendStageTimeoutSec
  readonly property var wmCommandMap: ({
      "hyprland": {
        on: ["hyprctl", "dispatch", "dpms", "on"],
        off: ["hyprctl", "dispatch", "dpms", "off"]
      },
      "niri": {
        on: ["niri", "msg", "action", "power-on-monitors"],
        off: ["niri", "msg", "action", "power-off-monitors"]
      }
    })
  readonly property var wmCmds: wmCommandMap[String(MainService.currentWM || "")]

  signal actionFired(string name)

  property bool rearmToken: true
  function rearmMonitors(): void {
    rearmToken = false;
    Qt.callLater(function () {
      rearmToken = true;
    });
  }

  onTotalTimeoutChanged: rearmMonitors()

  function setDpms(turnOn: bool): void {
    const nextOff = !turnOn;
    if (dpmsOffInSession === nextOff)
      return;
    dpmsOffInSession = nextOff;
    actionFired(turnOn ? "dpms-on" : "dpms-off");
    if (wmCmds)
      Utils.runCmd(turnOn ? wmCmds.on : wmCmds.off, undefined, idleDaemon);
    else
      Logger.warn("IdleService", "Unsupported WM for DPMS:", String(MainService.currentWM || ""));
  }

  function wake(): void {
    if (dpmsOffInSession)
      setDpms(true);
  }

  IdleInhibitor {
    enabled: idleDaemon.effectiveInhibited
    window: idleDaemon.window
  }

  IdleMonitor {
    id: lockMonitor
    enabled: idleDaemon.baseEnabled && idleDaemon.settings.lockEnabled && !LockService.locked
    respectInhibitors: idleDaemon.monitorRespectInhibitors
    timeout: idleDaemon.lockStageTimeoutSec
    onIsIdleChanged: (isIdle && !LockService.locked) ? (LockService.locked = true, idleDaemon.actionFired("lock")) : idleDaemon.wake()
  }

  IdleMonitor {
    id: dpmsMonitor
    enabled: idleDaemon.baseEnabled && idleDaemon.settings.dpmsEnabled
    respectInhibitors: idleDaemon.monitorRespectInhibitors
    timeout: idleDaemon.dpmsStageTimeoutSec
    onIsIdleChanged: isIdle ? idleDaemon.setDpms(false) : idleDaemon.wake()
  }

  IdleMonitor {
    id: suspendMonitor
    enabled: idleDaemon.baseEnabled && idleDaemon.settings.suspendEnabled
    respectInhibitors: idleDaemon.monitorRespectInhibitors
    timeout: idleDaemon.suspendStageTimeoutSec
    onIsIdleChanged: isIdle ? idleDaemon.actionFired("suspend") : idleDaemon.wake()
  }

  Connections {
    target: LockService
    function onLockedChanged() {
      if (!LockService.locked)
        idleDaemon.setDpms(true);
    }
  }
}
