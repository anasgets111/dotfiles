pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.Core
import qs.Services.Utils
import qs.Services

// IdleDaemon: lock -> dpms-off -> suspend with wake coalescing.
Singleton {
  id: idleDaemon

  property bool _dpmsOffInSession: false
  property bool _dpmsOnSinceLastOff: false
  property double _dpmsSettleUntilMs: 0
  property bool _enabledGate: true
  property int _holdCount: 0
  readonly property int _initialTimeoutSec: (function () {
      const next = LockService.locked ? (settings.dpmsEnabled ? settings.dpmsTimeoutSec : settings.suspendTimeoutSec) : (settings.lockEnabled ? settings.lockTimeoutSec : (settings.dpmsEnabled ? settings.dpmsTimeoutSec : settings.suspendTimeoutSec));
      return Math.max(1, next || 1);
    })()
  property double _lastDpmsOnMs: 0
  property double _lastWakeMs: 0
  property int _stageIndex: -1
  property var _stages: []
  property bool _unlockGraceActive: false
  property bool dpmsCommandsEnabled: true
  readonly property int dpmsOnDebounceMs: 400
  readonly property bool effectiveInhibited: (_holdCount > 0) || (settings.videoAutoInhibit && MediaService.anyVideoPlaying)
  property var window
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

  signal actionFired(string name) // "lock", "dpms-off", "dpms-on", "suspend"

  function _armNextStage() {
    _stageIndex += 1;
    if (_stageIndex >= _stages.length)
      return;
    const stageDelayMs = (_stages[_stageIndex].delaySec || 0) * 1000;
    if (stageDelayMs > 0) {
      stageTimer.interval = stageDelayMs;
      stageTimer.restart();
    } else
      Qt.callLater(idleDaemon._runCurrentStage);
  }

  // ========= Pipeline =========
  function _buildStages() {
    const stages = [];
    if (settings.lockEnabled && !LockService.locked)
      stages.push({
        name: "lock",
        delaySec: 0
      });
    if (settings.dpmsEnabled)
      stages.push({
        name: "dpms-off",
        delaySec: settings.dpmsTimeoutSec
      });
    else if (settings.suspendEnabled)
      stages.push({
        name: "suspend",
        delaySec: settings.suspendTimeoutSec
      });
    if (settings.dpmsEnabled && settings.suspendEnabled)
      stages.push({
        name: "suspend",
        delaySec: settings.suspendTimeoutSec
      });
    return stages;
  }
  function _cancelPipeline(reason) {
    if (_stageIndex === -1) {
      if (reason === "wake")
        _maybeDpmsOn("wake-ended");
      return;
    }
    stageTimer.stop();
    const explicitWake = (reason === "wake");
    if (_dpmsOffInSession) {
      idleDaemon.actionFired("dpms-on");
      if (explicitWake)
        _maybeDpmsOn("wake-after-dpms-off");
    } else if (explicitWake) {
      _maybeDpmsOn("wake-no-prior-off");
    }
    _stageIndex = -1;
    _dpmsOffInSession = false;
    if (_enabledGate) {
      _enabledGate = false;
      rearmTimer.restart();
    }
  }
  function _doDpmsOff() {
    if (_dpmsOffInSession)
      return;
    _dpmsOffInSession = true;
    _dpmsOnSinceLastOff = false;
    _dpmsSettleUntilMs = Date.now() + 1800;
    idleDaemon.actionFired("dpms-off");
    if (dpmsCommandsEnabled)
      _dpms(false);
  }
  function _dpms(turnOn) {
    const wm = String(MainService.currentWM || "");
    const cmds = wmCommandMap[wm];
    if (!cmds)
      return;
    if (turnOn && _dpmsOnSinceLastOff)
      return;
    try {
      const args = turnOn ? cmds.on : cmds.off;
      Utils.runCmd(args, function () {}, idleDaemon);
      _dpmsOnSinceLastOff = !!turnOn;
    } catch (e) {}
  }
  function _maybeDpmsOn(reason) {
    if (!dpmsCommandsEnabled)
      return;
    const now = Date.now();
    if (now - _lastDpmsOnMs < dpmsOnDebounceMs)
      return;
    _lastDpmsOnMs = now;
    _dpms(true);
  }
  function _runCurrentStage() {
    if (_stageIndex < 0 || _stageIndex >= _stages.length)
      return;
    const current = _stages[_stageIndex].name;
    if (current === "lock") {
      if (!LockService.locked) {
        LockService.locked = true;
        idleDaemon.actionFired("lock");
      }
      _armNextStage();
      return;
    }
    if (current === "dpms-off") {
      _doDpmsOff();
      _armNextStage();
      return;
    }
    if (current === "suspend") {
      idleDaemon.actionFired("suspend");
      return;
    }
  }
  function _startPipeline() {
    if (_stageIndex !== -1)
      return;
    _dpmsOffInSession = false;
    _stages = _buildStages();
    _stageIndex = -1;
    _armNextStage();
  }
  function hold(reason) {
    _holdCount += 1;
    return {
      token: Math.random().toString(36).slice(2),
      reason: String(reason || "")
    };
  }
  function release(token) {
    if (_holdCount > 0)
      _holdCount -= 1;
  }
  function toggle() {
    settings.enabled = !settings.enabled;
  }

  // Wake: throttled + coalesced dpms-on
  function wake(reason, surfaceTag) {
    const now = Date.now();
    if (_lastWakeMs && (now - _lastWakeMs) < 250)
      return;
    _lastWakeMs = now;
    if (_stageIndex !== -1)
      _cancelPipeline("wake");
    else
      _maybeDpmsOn("wake-no-pipeline");
  }

  onEffectiveInhibitedChanged: {
    if (effectiveInhibited)
      console.log("[IdleService] idle-inhibit ON reason=" + (_holdCount > 0 ? ("manual-hold(" + _holdCount + ")") : "") + ((settings.videoAutoInhibit && MediaService.anyVideoPlaying) ? ((_holdCount > 0 ? "+" : "") + "video-playing") : ""));
    else
      console.log("[IdleService] idle-inhibit OFF");
    if (effectiveInhibited && !LockService.locked)
      _cancelPipeline("inhibited");
  }

  // ========= Settings =========
  PersistentProperties {
    id: settings

    property bool dpmsEnabled: true
    property int dpmsTimeoutSec: 30
    property bool enabled: true
    property bool lockEnabled: true
    property int lockTimeoutSec: 300
    property bool respectInhibitors: true
    property bool suspendEnabled: false
    property int suspendTimeoutSec: 120
    property bool videoAutoInhibit: true

    reloadableId: "IdleDaemon"
  }

  // Inhibit compositor idle (timers remain separate)
  IdleInhibitor {
    enabled: idleDaemon.effectiveInhibited
    window: idleDaemon.window
  }

  // Idle edge detector
  IdleMonitor {
    enabled: idleDaemon._enabledGate && settings.enabled && (settings.lockEnabled || settings.dpmsEnabled || settings.suspendEnabled) && !idleDaemon._unlockGraceActive
    respectInhibitors: settings.respectInhibitors && !LockService.locked
    timeout: idleDaemon._initialTimeoutSec

    onIsIdleChanged: {
      if (isIdle) {
        Qt.callLater(idleDaemon._startPipeline);
      } else if (Date.now() >= idleDaemon._dpmsSettleUntilMs) {
        Qt.callLater(function () {
          idleDaemon._cancelPipeline("resume");
        });
      }
    }
  }

  Timer {
    id: stageTimer

    onTriggered: idleDaemon._runCurrentStage()
  }

  Timer {
    id: rearmTimer

    interval: 10

    onTriggered: idleDaemon._enabledGate = true
  }

  Timer {
    id: unlockGraceTimer

    interval: 2500

    onTriggered: idleDaemon._unlockGraceActive = false
  }
  Connections {
    function onLockedChanged() {
      if (!LockService.locked) {
        idleDaemon._unlockGraceActive = true;
        unlockGraceTimer.restart();
        idleDaemon._cancelPipeline("unlocked");
      }
      idleDaemon._enabledGate = false;
      rearmTimer.restart();
    }

    target: LockService
  }
}
