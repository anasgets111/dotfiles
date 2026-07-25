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

  readonly property int _displayPowerOffTimeoutSec: settings?.dpmsTimeoutSec ?? 30
  readonly property bool _dpmsDone: !displayPowerOffActionEnabled || displaysPoweredOff
  readonly property bool _lockDone: !lockActionEnabled || LockService.locked
  readonly property int _lockTimeoutSec: settings?.lockTimeoutSec ?? 300
  readonly property int _suspendTimeoutSec: settings?.suspendTimeoutSec ?? 120
  readonly property bool armed: idleEnabled && !inhibited
  readonly property bool automaticInhibitorActive: (settings?.videoAutoInhibit ?? true) && (MediaService.anyVideoPlaying || PrivacyService.cameraActive || PrivacyService.screenshareActive || PrivacyService.audioCaptureActive)
  readonly property bool displayPowerOffActionEnabled: (settings?.dpmsEnabled ?? true) && _displayPowerOffTimeoutSec > 0
  property bool displaysPoweredOff: false
  readonly property var flowSteps: lockAfterDisplayPowerOff ? ["displayPowerOff", "lock", "suspend"] : ["lock", "displayPowerOff", "suspend"]
  readonly property bool fullscreenInhibitorActive: WorkspaceService.fullscreenVisible
  readonly property bool idleEnabled: Settings.isLoaded && settings !== null && (settings.enabled ?? true)
  readonly property bool inhibited: manualInhibit || fullscreenInhibitorActive || automaticInhibitorActive
  readonly property bool lockActionEnabled: (settings?.lockEnabled ?? true) && _lockTimeoutSec > 0
  readonly property bool lockAfterDisplayPowerOff: settings?.lockAfterDpms ?? false
  property bool manualInhibit: false
  readonly property var settings: Settings.data?.idleService ?? null
  readonly property bool suspendActionEnabled: (settings?.suspendEnabled ?? false) && _suspendTimeoutSec > 0
  property QsWindow window

  function setDisplaysPowered(powered: bool): void {
    if (root.displaysPoweredOff === !powered)
      return;
    if (!CompositorService.setDisplaysPowered(powered)) {
      Logger.warn("IdleService", "DPMS not supported by the current compositor");
      return;
    }
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
  // Idle is counted from when a monitor subscribes, so each stage waits its own timeout
  // after its gate opens: the gates are the sequencing, not redundant with the timeouts.
  IdleStage {
    enabled: root.armed && root.lockActionEnabled && !LockService.locked && (!root.lockAfterDisplayPowerOff || root._dpmsDone)
    idleAction: () => LockService.requestLock()
    stageTimeout: root._lockTimeoutSec
  }
  IdleStage {
    enabled: root.armed && root.displayPowerOffActionEnabled && (root.lockAfterDisplayPowerOff || root._lockDone)
    idleAction: () => root.setDisplaysPowered(false)
    stageTimeout: root._displayPowerOffTimeoutSec
  }
  IdleStage {
    enabled: root.armed && root.suspendActionEnabled && root._lockDone && root._dpmsDone
    idleAction: () => PowerManagementService.suspend()
    stageTimeout: root._suspendTimeoutSec
  }

  component IdleStage: IdleMonitor {
    required property var idleAction
    readonly property bool stageRespectInhibitors: !LockService.locked && (root.settings?.respectInhibitors ?? true)
    required property int stageTimeout

    // timeout/respectInhibitors are Qt bindable: binding them never re-registers the
    // wayland notification, so isIdle silently stops. These seed; the handlers must assign.
    respectInhibitors: stageRespectInhibitors
    timeout: stageTimeout

    onIsIdleChanged: if (isIdle)
      idleAction()
    onStageRespectInhibitorsChanged: respectInhibitors = stageRespectInhibitors
    onStageTimeoutChanged: timeout = stageTimeout
  }
}
