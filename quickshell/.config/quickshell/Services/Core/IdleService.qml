pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.Core
import qs.Services.Utils
import qs.Services
import qs.Config

// IdleDaemon: Manages idle pipeline (lock -> dpms-off -> suspend) with wake coalescing.
// Flow: Unlocked idle → lock (0s) → dpms (dpmsTimeoutSec) → suspend (suspendTimeoutSec).
// Locked interact → idle: dpms (dpmsTimeoutSec total, no extra delay).
Singleton {
  id: idleDaemon

  readonly property var settings: Settings.data.idleService
  readonly property int wakeDebounceMs: 250
  readonly property int rearmDelayMs: 10
  readonly property int unlockGraceMs: 2500
  readonly property int dpmsOnDebounceMs: 400

  QtObject {
    id: state
    property bool dpmsOffInSession: false
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
  }

  // Build the linear pipeline based on settings and current lock state
  function buildStages(): var {
    const stages = [];
    if (settings.lockEnabled && !LockService.locked)
      stages.push({
        name: "lock",
        delaySec: 0
      });

    if (settings.dpmsEnabled) {
      const dpmsDelay = LockService.locked ? 0 : settings.dpmsTimeoutSec;
      stages.push({
        name: "dpms-off",
        delaySec: dpmsDelay
      });
    }

    if (settings.suspendEnabled)
      stages.push({
        name: "suspend",
        delaySec: settings.suspendTimeoutSec
      });

    return stages;
  }

  function armNextStage(): void {
    state.currentStageIndex += 1;
    if (state.currentStageIndex >= state.stages.length)
      return;

    const stage = state.stages[state.currentStageIndex];
    const ms = (stage.delaySec || 0) * 1000;
    if (ms > 0) {
      stageTimer.interval = ms;
      stageTimer.restart();
    } else {
      Qt.callLater(idleDaemon.runCurrentStage);
    }
  }

  function cancelPipeline(reason: string): void {
    if (state.currentStageIndex === -1) {
      if (reason === "wake")
        maybeDpmsOn("wake-ended");
      return;
    }
    stageTimer.stop();
    const explicitWake = (reason === "wake");
    if (state.dpmsOffInSession || explicitWake)
      maybeDpmsOn("cancel/" + reason);
    resetPipelineState();
    rearm();
  }

  function rearm(): void {
    if (!state.rearmGate)
      return;
    state.rearmGate = false;
    rearmTimer.restart();
  }

  function dpms(turnOn: bool): void {
    if (!dpmsCommandsEnabled)
      return;

    const wm = String(MainService.currentWM || "");
    const cmds = wmCommandMap[wm];
    if (!cmds)
      return;

    Utils.runCmd(turnOn ? cmds.on : cmds.off, function () {}, idleDaemon);
  }

  function doDpmsOff(): void {
    if (state.dpmsOffInSession)
      return;
    state.dpmsOffInSession = true;
    actionFired("dpms-off");
    dpms(false);
  }

  function maybeDpmsOn(reason: string): void {
    if (!dpmsCommandsEnabled)
      return;
    const now = Date.now();
    if (now - state.lastDpmsOnMs < dpmsOnDebounceMs)
      return;
    state.lastDpmsOnMs = now;
    actionFired("dpms-on");
    dpms(true);
  }

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
      token: token,
      reason: String(reason || "")
    };
  }

  function release(tokenOrObj: var): void {
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
    if (state.lastWakeMs && (now - state.lastWakeMs) < wakeDebounceMs)
      return;
    state.lastWakeMs = now;
    if (state.currentStageIndex !== -1)
      cancelPipeline("wake");
    else
      maybeDpmsOn("wake-no-pipeline");
  }

  onEffectiveInhibitedChanged: {
    if (effectiveInhibited && !LockService.locked)
      cancelPipeline("inhibited");
  }

  IdleInhibitor {
    enabled: idleDaemon.effectiveInhibited
    window: idleDaemon.window
  }

  IdleMonitor {
    enabled: state.rearmGate && idleDaemon.settings.enabled && (idleDaemon.settings.lockEnabled || idleDaemon.settings.dpmsEnabled || idleDaemon.settings.suspendEnabled) && !state.unlockGraceActive
    respectInhibitors: idleDaemon.settings.respectInhibitors && !LockService.locked
    timeout: idleDaemon.initialTimeoutSec
    onIsIdleChanged: {
      if (isIdle) {
        Qt.callLater(idleDaemon.startPipeline);
        Logger.log("IdleService", "system idle detected, starting pipeline");
      } else {
        Qt.callLater(function () {
          idleDaemon.wake("input");
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
      idleDaemon.rearm();
    }
  }
}
