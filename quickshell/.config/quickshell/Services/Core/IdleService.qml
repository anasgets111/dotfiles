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
  readonly property bool automaticInhibitorActive: videoAutoInhibitEnabled && (MediaService.anyVideoPlaying || PrivacyService.cameraActive || PrivacyService.screenshareActive || PrivacyService.audioCaptureActive)
  readonly property bool displayPowerOffActionEnabled: displayPowerOffEnabled && _displayPowerOffTimeoutSec > 0
  readonly property bool displayPowerOffEnabled: settings?.dpmsEnabled ?? true
  property bool displaysPoweredOff: false
  readonly property bool fullscreenInhibitorActive: WorkspaceService.fullscreenVisible
  readonly property bool idleEnabled: Settings.isLoaded && settings !== null && (settings.enabled ?? true)
  readonly property bool inhibited: manualInhibit || fullscreenInhibitorActive || automaticInhibitorActive
  readonly property bool lockActionEnabled: lockEnabled && _lockTimeoutSec > 0
  readonly property bool lockAfterDisplayPowerOff: settings?.lockAfterDpms ?? false
  readonly property bool lockEnabled: settings?.lockEnabled ?? true
  property bool manualInhibit: false
  readonly property bool respectInhibitorsEnabled: settings?.respectInhibitors ?? true
  readonly property var settings: Settings.data?.idleService ?? null
  readonly property bool suspendActionEnabled: suspendEnabled && _suspendTimeoutSec > 0
  readonly property bool suspendEnabled: settings?.suspendEnabled ?? false
  readonly property bool videoAutoInhibitEnabled: settings?.videoAutoInhibit ?? true
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
    timeout: root._lockTimeoutSec
  }
  IdleStage {
    idleAction: () => root.setDisplaysPowered(false)
    enabled: root.armed && root.displayPowerOffActionEnabled && (root.lockAfterDisplayPowerOff || root._lockDone)
    timeout: root._displayPowerOffTimeoutSec
  }
  IdleStage {
    idleAction: () => PowerManagementService.suspend()
    enabled: root.armed && root.suspendActionEnabled && root._lockDone && root._dpmsDone
    timeout: root._suspendTimeoutSec
  }

  component IdleStage: IdleMonitor {
    required property var idleAction

    respectInhibitors: !LockService.locked && root.respectInhibitorsEnabled

    onIsIdleChanged: if (isIdle)
      idleAction()
  }
}
