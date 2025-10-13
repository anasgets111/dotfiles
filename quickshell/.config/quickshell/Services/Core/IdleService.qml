pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.Core
import qs.Services.Utils
import qs.Services
import qs.Config

Singleton {
  id: root

  readonly property bool baseEnabled: rearmToken && monitorsEnabled
  property bool dpmsOffInSession: false
  readonly property int dpmsStageTimeoutSec: settings.dpmsEnabled ? (lockStageTimeoutSec + settings.dpmsTimeoutSec) : lockStageTimeoutSec
  readonly property bool effectiveInhibited: settings.videoAutoInhibit && MediaService.anyVideoPlaying
  readonly property int lockStageTimeoutSec: (!LockService.locked && settings.lockEnabled) ? settings.lockTimeoutSec : 0
  readonly property bool monitorRespectInhibitors: settings.respectInhibitors && !LockService.locked
  readonly property bool monitorsEnabled: Settings.isLoaded && settings.enabled && (settings.lockEnabled || settings.dpmsEnabled || settings.suspendEnabled)
  property bool rearmToken: true
  readonly property var settings: Settings.data.idleService
  readonly property int suspendStageTimeoutSec: settings.suspendEnabled ? (dpmsStageTimeoutSec + settings.suspendTimeoutSec) : dpmsStageTimeoutSec
  property QsWindow window
  readonly property var wmCmds: wmCommandMap[String(MainService.currentWM || "")]
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

  signal actionFired(name: string)

  function rearmMonitors(): void {
    rearmToken = false;
    Qt.callLater(() => rearmToken = true);
  }

  function setDpms(turnOn: bool): void {
    if (dpmsOffInSession === !turnOn)
      return;
    dpmsOffInSession = !turnOn;
    actionFired(turnOn ? "dpms-on" : "dpms-off");

    if (wmCmds)
      Utils.runCmd(turnOn ? wmCmds.on : wmCmds.off);
    else
      Logger.warn("IdleService", `Unsupported WM for DPMS: ${MainService.currentWM || "unknown"}`);
  }

  function wake(): void {
    if (dpmsOffInSession)
      setDpms(true);
  }

  onSuspendStageTimeoutSecChanged: rearmMonitors()

  IdleInhibitor {
    enabled: root.effectiveInhibited
    window: root.window
  }

  IdleMonitor {
    id: lockMonitor

    enabled: root.baseEnabled && root.settings.lockEnabled && !LockService.locked
    respectInhibitors: root.monitorRespectInhibitors
    timeout: root.lockStageTimeoutSec

    onIsIdleChanged: {
      if (isIdle) {
        LockService.locked = true;
        root.actionFired("lock");
      } else {
        root.wake();
      }
    }
  }

  IdleMonitor {
    id: dpmsMonitor

    enabled: root.baseEnabled && root.settings.dpmsEnabled
    respectInhibitors: root.monitorRespectInhibitors
    timeout: root.dpmsStageTimeoutSec

    onIsIdleChanged: isIdle ? root.setDpms(false) : root.wake()
  }

  IdleMonitor {
    id: suspendMonitor

    enabled: root.baseEnabled && root.settings.suspendEnabled
    respectInhibitors: root.monitorRespectInhibitors
    timeout: root.suspendStageTimeoutSec

    onIsIdleChanged: isIdle ? root.actionFired("suspend") : root.wake()
  }

  Connections {
    function onLockedChanged() {
      if (!LockService.locked)
        root.wake();
    }

    target: LockService
  }
}
