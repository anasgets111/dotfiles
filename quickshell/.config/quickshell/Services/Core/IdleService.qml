pragma ComponentBehavior: Bound
pragma Singleton
import Quickshell
import Quickshell.Wayland
import qs.Services.Core
import qs.Services.Utils
import qs.Services.SystemInfo
import qs.Services.WM
import qs.Config

Singleton {
  id: root

  readonly property var _activeProfile: BatteryService.isOnBattery ? (settings?.batteryProfile ?? null) : (settings?.acProfile ?? null)
  readonly property int displayPowerOffTimeoutSec: _activeProfile?.dpmsTimeoutSec ?? 30
  readonly property bool _dpmsDone: !displayPowerOffActionEnabled || displaysPoweredOff
  readonly property bool _lockDone: !lockActionEnabled || LockService.locked
  readonly property int lockTimeoutSec: _activeProfile?.lockTimeoutSec ?? 300
  readonly property int suspendTimeoutSec: _activeProfile?.suspendTimeoutSec ?? 120
  readonly property bool armed: idleEnabled && !inhibited
  readonly property bool automaticInhibitorActive: (settings?.videoAutoInhibit ?? true) && (MediaService.anyVideoPlaying || PrivacyService.cameraActive || PrivacyService.screenshareActive || PrivacyService.audioCaptureActive)
  readonly property bool displayPowerOffActionEnabled: (_activeProfile?.dpmsEnabled ?? true) && displayPowerOffTimeoutSec > 0
  property bool displaysPoweredOff: false
  readonly property bool fullscreenInhibitorActive: WorkspaceService.fullscreenVisible
  readonly property bool idleEnabled: Settings.isLoaded && settings !== null && (settings.enabled ?? true)
  readonly property bool inhibited: manualInhibit || fullscreenInhibitorActive || automaticInhibitorActive
  readonly property bool lockActionEnabled: (_activeProfile?.lockEnabled ?? true) && lockTimeoutSec > 0
  readonly property bool lockAfterDisplayPowerOff: _activeProfile?.lockAfterDpms ?? false
  property bool manualInhibit: false
  readonly property var settings: Settings.data?.idleService ?? null
  readonly property bool suspendActionEnabled: (_activeProfile?.suspendEnabled ?? false) && suspendTimeoutSec > 0
  property QsWindow window

  function setDisplaysPowered(powered: bool): void {
    if (root.displaysPoweredOff === !powered)
      return;
    if (!CompositorService.setDisplaysPowered(powered)) {
      return;
    }
    KeyboardBacklightService.setBlanked(!powered);
    root.displaysPoweredOff = !powered;
  }

  IdleInhibitor {
    enabled: root.inhibited
    window: root.window
  }
  IdleMonitor {
    respectInhibitors: false
    timeout: 1

    onIsIdleChanged: if (!isIdle)
      root.setDisplaysPowered(true)
  }
  IdleStage {
    enabled: root.armed && root.lockActionEnabled && !LockService.locked && (!root.lockAfterDisplayPowerOff || root._dpmsDone)
    idleAction: () => LockService.requestLock()
    stageTimeout: root.lockTimeoutSec
  }
  IdleStage {
    enabled: root.armed && root.displayPowerOffActionEnabled && (root.lockAfterDisplayPowerOff || root._lockDone)
    idleAction: () => root.setDisplaysPowered(false)
    stageTimeout: root.displayPowerOffTimeoutSec
  }
  IdleStage {
    enabled: root.armed && root.suspendActionEnabled && root._lockDone && root._dpmsDone
    idleAction: () => PowerManagementService.suspend()
    stageTimeout: root.suspendTimeoutSec
  }

  component IdleStage: IdleMonitor {
    required property var idleAction
    readonly property bool stageRespectInhibitors: !LockService.locked && (root.settings?.respectInhibitors ?? true)
    required property int stageTimeout

    respectInhibitors: stageRespectInhibitors
    timeout: stageTimeout

    onIsIdleChanged: if (isIdle)
      idleAction()
    onStageRespectInhibitorsChanged: respectInhibitors = stageRespectInhibitors
    onStageTimeoutChanged: timeout = stageTimeout
  }
}
