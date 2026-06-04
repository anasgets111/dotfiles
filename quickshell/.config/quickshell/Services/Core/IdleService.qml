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

  readonly property bool armed: idleEnabled && !inhibited
  readonly property bool autoInhibitorActive: MediaService.anyVideoPlaying || PrivacyService.cameraActive || PrivacyService.screenshareActive || PrivacyService.audioCaptureActive
  readonly property bool canLock: armed && settings.lockEnabled && !LockService.locked && (!settings.lockAfterDpms || !settings.dpmsEnabled || displaysPoweredOff)
  readonly property bool canPowerOffDisplays: armed && settings.dpmsEnabled && (settings.lockAfterDpms || LockService.locked || !settings.lockEnabled)
  readonly property bool canSuspend: armed && settings.suspendEnabled && displaysPoweredOff && (!settings.lockEnabled || LockService.locked)
  property bool displaysPoweredOff: false
  readonly property bool fullscreenInhibitorActive: WorkspaceService.fullscreenVisible
  readonly property bool idleEnabled: Settings.isLoaded && settings !== null && settings.enabled
  readonly property bool inhibited: manualInhibit || fullscreenInhibitorActive || videoInhibitorActive
  property bool manualInhibit: false
  readonly property bool respectInhibitors: !LockService.locked && (settings?.respectInhibitors ?? true)
  readonly property var settings: Settings.data?.idleService ?? null
  readonly property bool videoInhibitorActive: (settings?.videoAutoInhibit ?? false) && autoInhibitorActive
  property QsWindow window

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
    timeout: root.settings?.lockTimeoutSec ?? 0
  }

  IdleStage {
    enabled: root.canPowerOffDisplays
    idleAction: () => root.setDisplaysPowered(false)
    timeout: root.settings?.dpmsTimeoutSec ?? 0
  }

  IdleStage {
    enabled: root.canSuspend
    idleAction: () => PowerManagementService.suspend()
    timeout: root.settings?.suspendTimeoutSec ?? 0
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

    respectInhibitors: root.respectInhibitors

    onIsIdleChanged: isIdle ? idleAction() : root.wakeDisplays()
  }
}
