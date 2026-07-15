pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.Core
import qs.Services.Utils
import qs.Services.SystemInfo
import qs.Services.WM
import qs.Config

Singleton {
  id: root

  readonly property int _displayPowerOffTimeoutSec: settings?.dpmsTimeoutSec ?? 30
  readonly property int _lockTimeoutSec: settings?.lockTimeoutSec ?? 300
  readonly property int _suspendTimeoutSec: settings?.suspendTimeoutSec ?? 120
  readonly property bool armed: idleEnabled && !inhibited
  readonly property bool autoInhibitorActive: MediaService.anyVideoPlaying || PrivacyService.cameraActive || PrivacyService.screenshareActive || PrivacyService.audioCaptureActive
  readonly property bool canLock: armed && lockActionEnabled && !LockService.locked && (!lockAfterDisplayPowerOff || !displayPowerOffActionEnabled || displaysPoweredOff)
  readonly property bool canPowerOffDisplays: armed && displayPowerOffActionEnabled && (lockAfterDisplayPowerOff || LockService.locked || !lockActionEnabled)
  readonly property bool canSuspend: armed && suspendActionEnabled && (!displayPowerOffActionEnabled || displaysPoweredOff) && (!lockActionEnabled || LockService.locked)
  readonly property bool displayPowerOffActionEnabled: displayPowerOffEnabled && _displayPowerOffTimeoutSec > 0
  readonly property bool displayPowerOffEnabled: settings?.dpmsEnabled ?? true
  readonly property real displayPowerOffTimeoutMin: _secToMin(_displayPowerOffTimeoutSec)
  property bool displaysPoweredOff: false
  readonly property int enabledActionCount: (lockActionEnabled ? 1 : 0) + (suspendActionEnabled ? 1 : 0) + (displayPowerOffActionEnabled ? 1 : 0)
  readonly property var flowSteps: lockAfterDisplayPowerOff ? ["displayPowerOff", "lock", "suspend"] : ["lock", "displayPowerOff", "suspend"]
  readonly property bool fullscreenInhibitorActive: WorkspaceService.fullscreenVisible
  readonly property bool idleEnabled: Settings.isLoaded && settings !== null && (settings.enabled ?? true)
  readonly property bool inhibited: manualInhibit || fullscreenInhibitorActive || videoInhibitorActive
  readonly property bool lockActionEnabled: lockEnabled && _lockTimeoutSec > 0
  readonly property bool lockAfterDisplayPowerOff: settings?.lockAfterDpms ?? false
  readonly property bool lockEnabled: settings?.lockEnabled ?? true
  readonly property real lockTimeoutMin: _secToMin(_lockTimeoutSec)
  property bool manualInhibit: false
  readonly property bool respectInhibitors: !LockService.locked && respectInhibitorsEnabled
  readonly property bool respectInhibitorsEnabled: settings?.respectInhibitors ?? true
  readonly property var settings: Settings.data?.idleService ?? null
  readonly property bool suspendActionEnabled: suspendEnabled && _suspendTimeoutSec > 0
  readonly property bool suspendEnabled: settings?.suspendEnabled ?? false
  readonly property real suspendTimeoutMin: _secToMin(_suspendTimeoutSec)
  readonly property bool videoAutoInhibitEnabled: settings?.videoAutoInhibit ?? true
  readonly property bool videoInhibitorActive: videoAutoInhibitEnabled && autoInhibitorActive
  property QsWindow window

  function _minToSec(value: real): int {
    const num = Number(value);
    return Math.round(Math.max(0, Number.isFinite(num) ? num : 0) * 60);
  }
  function _secToMin(value: int): real {
    const num = Number(value);
    return Math.max(0, Number.isFinite(num) ? num : 0) / 60;
  }
  function _setIdleSetting(key: string, value: var): void {
    if (!root.settings)
      return;
    root.settings[key] = value;
  }
  function setDisplayPowerOffEnabled(value: bool): void {
    root._setIdleSetting("dpmsEnabled", !!value);
  }
  function setDisplayPowerOffTimeoutMin(value: real): void {
    root._setIdleSetting("dpmsTimeoutSec", root._minToSec(value));
  }
  function setDisplaysPowered(powered: bool): void {
    const shouldBePoweredOff = !powered;
    if (root.displaysPoweredOff === shouldBePoweredOff)
      return;
    if (!CompositorService.setDisplaysPowered(powered)) {
      Logger.warn("IdleService", "DPMS not supported by the current compositor");
      return;
    }
    root.displaysPoweredOff = shouldBePoweredOff;
  }
  function setIdleEnabled(value: bool): void {
    root._setIdleSetting("enabled", !!value);
  }
  function setLockAfterDisplayPowerOff(value: bool): void {
    root._setIdleSetting("lockAfterDpms", !!value);
  }
  function setLockEnabled(value: bool): void {
    root._setIdleSetting("lockEnabled", !!value);
  }
  function setLockTimeoutMin(value: real): void {
    root._setIdleSetting("lockTimeoutSec", root._minToSec(value));
  }
  function setRespectInhibitors(value: bool): void {
    root._setIdleSetting("respectInhibitors", !!value);
  }
  function setSuspendEnabled(value: bool): void {
    root._setIdleSetting("suspendEnabled", !!value);
  }
  function setSuspendTimeoutMin(value: real): void {
    root._setIdleSetting("suspendTimeoutSec", root._minToSec(value));
  }
  function setVideoAutoInhibit(value: bool): void {
    root._setIdleSetting("videoAutoInhibit", !!value);
  }
  function wakeDisplays(): void {
    if (root.displaysPoweredOff)
      root.setDisplaysPowered(true);
  }

  IdleInhibitor {
    enabled: root.inhibited
    window: root.window
  }
  IdleStage {
    enabled: root.canLock
    idleAction: () => LockService.requestLock()
    timeout: root._lockTimeoutSec
  }
  IdleStage {
    enabled: root.canPowerOffDisplays
    idleAction: () => root.setDisplaysPowered(false)
    timeout: root._displayPowerOffTimeoutSec
    wakesDisplays: true
  }
  IdleStage {
    enabled: root.canSuspend
    idleAction: () => PowerManagementService.suspend()
    timeout: root._suspendTimeoutSec
  }
  Connections {
    function onLockedChanged(): void {
      if (!LockService.locked)
        root.wakeDisplays();
    }

    target: LockService
  }

  component IdleStage: IdleMonitor {
    required property var idleAction
    property bool wakesDisplays: false

    respectInhibitors: root.respectInhibitors

    onIsIdleChanged: {
      if (isIdle)
        idleAction();
      else if (enabled && wakesDisplays)
        root.wakeDisplays();
    }
  }
}
