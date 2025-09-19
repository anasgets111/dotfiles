pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.Core
import qs.Services.Utils
import qs.Services

// IdleDaemon: Manages idle pipeline (lock -> dpms-off -> suspend) with wake coalescing.
// Flow: Unlocked idle → lock (0s) → dpms (dpmsTimeoutSec) → suspend (suspendTimeoutSec).
// Locked interact → idle: dpms (dpmsTimeoutSec total, no extra delay).
Singleton {
  id: idleDaemon

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
  readonly property int wakeDebounceMs: 250
  readonly property int dpmsSettleMs: 1800
  readonly property int rearmDelayMs: 10
  readonly property int unlockGraceMs: 2500
  readonly property int dpmsOnDebounceMs: 400
  QtObject {
    id: state
    // Idle pipeline & DPMS bookkeeping (internal only)
    property bool dpmsOffInSession: false
    property bool dpmsAlreadyTurnedOn: false
    property double dpmsSettleUntilMs: 0
    property bool rearmGate: true
    property int holdCount: 0
    property var holdTokens: ({})
    property double lastDpmsOnMs: 0
    property double lastWakeMs: 0
    property int currentStageIndex: -1
    property var stages: []
    property bool unlockGraceActive: false
  }
  property bool dpmsCommandsEnabled: true
  property var window
  readonly property int initialTimeoutSec: {
    if (LockService.locked) {
      return settings.dpmsEnabled ? settings.dpmsTimeoutSec : settings.suspendTimeoutSec;
    } else {
      return settings.lockEnabled ? settings.lockTimeoutSec : (settings.dpmsEnabled ? settings.dpmsTimeoutSec : settings.suspendTimeoutSec);
    }
  }
  readonly property bool effectiveInhibited: (state.holdCount > 0) || (settings.videoAutoInhibit && MediaService.anyVideoPlaying)
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

  signal actionFired(string name)

  function resetPipelineState(): void {
    state.currentStageIndex = -1;
    state.dpmsOffInSession = false;
    state.dpmsAlreadyTurnedOn = false;
  }

  function armNextStage(): void {
    state.currentStageIndex += 1;
    if (state.currentStageIndex >= state.stages.length) {
      return;
    }

    const stage = state.stages[state.currentStageIndex];
    const stageDelayMs = (stage.delaySec || 0) * 1000;

    if (stageDelayMs > 0) {
      stageTimer.interval = stageDelayMs;
      stageTimer.restart();
    } else {
      Qt.callLater(idleDaemon.runCurrentStage);
    }
  }

  // Build stages: Sequential actions based on settings and lock state.
  // - Unlocked: lock (0s) -> dpms (full delay) -> suspend (full delay).
  // - Locked: Skip lock; dpms (0s delay for immediate on idle detect) -> suspend (full delay).
  function buildStages(): var {
    const stages = [];
    if (settings.lockEnabled && !LockService.locked) {
      stages.push({
        "name": "lock",
        "delaySec": 0
      });
    }

    // DPMS stage: If enabled; delay=0 if locked (avoids double-wait post-interact).
    if (settings.dpmsEnabled) {
      const dpmsDelay = LockService.locked ? 0 : settings.dpmsTimeoutSec;
      stages.push({
        "name": "dpms-off",
        "delaySec": dpmsDelay
      });
    }

    // Suspend stage: If enabled (always full delay from prior).
    if (settings.suspendEnabled) {
      stages.push({
        "name": "suspend",
        "delaySec": settings.suspendTimeoutSec
      });
    }

    return stages;
  }

  function cancelPipeline(reason: string): void {
    if (state.currentStageIndex === -1) {
      if (reason === "wake") {
        maybeDpmsOn("wake-ended");
      }
      return;
    }
    stageTimer.stop();
    const explicitWake = (reason === "wake");
    if (state.dpmsOffInSession) {
      actionFired("dpms-on");
      if (explicitWake) {
        maybeDpmsOn("wake-after-dpms-off");
      }
    } else if (explicitWake) {
      maybeDpmsOn("wake-no-prior-off");
    }
    resetPipelineState();
    if (state.rearmGate) {
      state.rearmGate = false;
      rearmTimer.restart();
    }
  }

  // Execute DPMS off (idempotent).
  function doDpmsOff(): void {
    if (state.dpmsOffInSession) {
      return;
    }
    state.dpmsOffInSession = true;
    state.dpmsAlreadyTurnedOn = false;
    state.dpmsSettleUntilMs = Date.now() + dpmsSettleMs;

    actionFired("dpms-off");
    if (dpmsCommandsEnabled) {
      dpms(false);
    }
  }

  function dpms(turnOn: bool): void {
    if (!dpmsCommandsEnabled) {
      return;
    }
    const wm = String(MainService.currentWM || "");
    const cmds = wmCommandMap[wm];
    if (!cmds) {
      return;
    }
    if (turnOn && state.dpmsAlreadyTurnedOn) {
      return;
    }
    const args = turnOn ? cmds.on : cmds.off;
    Utils.runCmd(args, function () {}, idleDaemon);
    state.dpmsAlreadyTurnedOn = !!turnOn;
  }

  // Conditional DPMS on (debounced).
  function maybeDpmsOn(reason: string): void {
    if (!dpmsCommandsEnabled) {
      return;
    }
    const now = Date.now();
    if (now - state.lastDpmsOnMs < dpmsOnDebounceMs) {
      return;
    }
    state.lastDpmsOnMs = now;
    dpms(true);
  }

  // Run current stage action.
  function runCurrentStage(): void {
    if (state.currentStageIndex < 0 || state.currentStageIndex >= state.stages.length)
      return;
    const stageName = state.stages[state.currentStageIndex].name;
    if (stageName === "lock") {
      if (!LockService.locked) {
        LockService.locked = true;
        actionFired("lock");
      }
      armNextStage();
      return;
    }
    if (stageName === "dpms-off") {
      doDpmsOff();
      armNextStage();
      return;
    }
    if (stageName === "suspend") {
      actionFired("suspend");
      return;
    }
  }

  function startPipeline(): void {
    if (state.currentStageIndex !== -1)
      return;
    state.dpmsOffInSession = false;
    state.stages = buildStages();
    state.currentStageIndex = -1;
    armNextStage();
  }

  function hold(reason: string): var {
    state.holdCount += 1;
    const token = Math.random().toString(36).slice(2);
    state.holdTokens[token] = true;
    return {
      "token": token,
      "reason": String(reason || "")
    };
  }

  function release(tokenOrObj: var) {
    const token = tokenOrObj && tokenOrObj.token ? tokenOrObj.token : tokenOrObj;
    if (token && state.holdTokens[token]) {
      delete state.holdTokens[token];
      if (state.holdCount > 0)
        state.holdCount -= 1;
    }
  }

  function toggle(): void {
    settings.enabled = !settings.enabled;
  }

  function wake(reason: string): void {
    const now = Date.now();
    if (state.lastWakeMs && (now - state.lastWakeMs) < wakeDebounceMs) {
      return;
    }
    state.lastWakeMs = now;
    if (state.currentStageIndex !== -1)
      cancelPipeline("wake");
    else
      maybeDpmsOn("wake-no-pipeline");
  }

  onEffectiveInhibitedChanged: {
    if (effectiveInhibited) {
      const parts = [];
      if (state.holdCount > 0)
        parts.push("manual-hold(" + state.holdCount + ")");
      if (settings.videoAutoInhibit && MediaService.anyVideoPlaying)
        parts.push("video-playing");
      Logger.log("IdleService", "idle-inhibit ON", "reason=", parts.join("+"));
    } else
      Logger.log("IdleService", "idle-inhibit OFF");

    if (effectiveInhibited && !LockService.locked)
      cancelPipeline("inhibited");
  }

  IdleInhibitor {
    enabled: idleDaemon.effectiveInhibited
    window: idleDaemon.window
  }

  IdleMonitor {
    enabled: state.rearmGate && settings.enabled && (settings.lockEnabled || settings.dpmsEnabled || settings.suspendEnabled) && !state.unlockGraceActive
    respectInhibitors: settings.respectInhibitors && !LockService.locked
    timeout: idleDaemon.initialTimeoutSec

    onIsIdleChanged: {
      if (isIdle) {
        Qt.callLater(idleDaemon.startPipeline);
        Logger.log("IdleService", "system idle detected, starting pipeline");
      } else if (Date.now() >= state.dpmsSettleUntilMs) {
        Qt.callLater(function () {
          idleDaemon.cancelPipeline("resume");
        });
      }
    }
  }

  Timer {
    id: stageTimer
    onTriggered: idleDaemon.runCurrentStage()
  }

  Timer {
    id: rearmTimer
    interval: idleDaemon.rearmDelayMs
    onTriggered: state.rearmGate = true
  }

  Timer {
    id: unlockGraceTimer
    interval: idleDaemon.unlockGraceMs
    onTriggered: state.unlockGraceActive = false
  }

  Connections {
    target: LockService

    function onLockedChanged() {
      if (!LockService.locked) {
        state.unlockGraceActive = true;
        unlockGraceTimer.restart();
        idleDaemon.cancelPipeline("unlocked");
      }
      state.rearmGate = false;
      rearmTimer.restart();
    }
  }
}
