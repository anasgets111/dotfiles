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
  readonly property int _lockTimeoutSec: settings?.lockTimeoutSec ?? 300
  readonly property int _suspendTimeoutSec: settings?.suspendTimeoutSec ?? 120
  readonly property bool _dpmsDone: !displayPowerOffActionEnabled || displaysPoweredOff
  readonly property bool _lockDone: !lockActionEnabled || LockService.locked
  readonly property bool armed: idleEnabled && !inhibited
  readonly property bool automaticInhibitorActive: (settings?.videoAutoInhibit ?? true) && (MediaService.anyVideoPlaying || PrivacyService.cameraActive || PrivacyService.screenshareActive || PrivacyService.audioCaptureActive)
  readonly property bool displayPowerOffActionEnabled: (settings?.dpmsEnabled ?? true) && _displayPowerOffTimeoutSec > 0
  property bool displaysPoweredOff: false
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
  IdleStage {
    idleAction: () => LockService.requestLock()
    enabled: root.armed && root.lockActionEnabled && !LockService.locked && (!root.lockAfterDisplayPowerOff || root._dpmsDone)
    stageTimeout: root._lockTimeoutSec
  }
  IdleStage {
    idleAction: () => root.setDisplaysPowered(false)
    enabled: root.armed && root.displayPowerOffActionEnabled && (root.lockAfterDisplayPowerOff || root._lockDone)
    stageTimeout: root._displayPowerOffTimeoutSec
  }
  IdleStage {
    idleAction: () => PowerManagementService.suspend()
    enabled: root.armed && root.suspendActionEnabled && root._lockDone && root._dpmsDone
    stageTimeout: root._suspendTimeoutSec
  }

  component IdleStage: IdleMonitor {
    required property var idleAction
    readonly property bool stageRespectInhibitors: !LockService.locked && (root.settings?.respectInhibitors ?? true)
    required property int stageTimeout

    // Quickshell exposes timeout and respectInhibitors as Qt bindable properties, and a
    // QML binding on those never reaches IdleMonitor::updateNotification, so the wayland
    // notification is never re-registered and isIdle stops firing. Assigning them
    // imperatively does re-register. These bindings only seed the first value; the
    // handlers below replace them.
    respectInhibitors: stageRespectInhibitors
    timeout: stageTimeout

    onIsIdleChanged: if (isIdle)
      idleAction()
    onStageRespectInhibitorsChanged: respectInhibitors = stageRespectInhibitors
    onStageTimeoutChanged: timeout = stageTimeout
  }
}
