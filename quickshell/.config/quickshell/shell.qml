//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1

pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import Quickshell
import qs.Modules.Global
import qs.Modules.Notification
import qs.Modules.OSD
import qs.Modules.Shell
import qs.Services
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.Utils
import qs.Services.WM

ShellRoot {
  id: root

  readonly property var fullscreenPopupContentType: WorkspaceService.fullscreenPopupContentTypes.get(MonitorService.activeMain) ?? null
  readonly property var ipc: IPC
  readonly property var sysInfo: SystemInfoService

  MainScreen {
    modelData: MonitorService.activeMainScreen
  }
  LazyLoader {
    active: NotificationService.visibleNotifications.length > 0 && root.fullscreenPopupContentType === null

    component: NotificationPopup {
      modelData: MonitorService.activeMainScreen
    }
  }
  LazyLoader {
    active: OSDService.visible && (root.fullscreenPopupContentType === null || root.fullscreenPopupContentType === "video")

    component: OSDPopup {
      modelData: MonitorService.activeMainScreen
    }
  }
  LazyLoader {
    // Settings load after QML defaults; synchronous activation avoids an activeAsync cancellation race.
    active: InputDisplayService.enabled

    component: InputDisplayPopup {
      modelData: MonitorService.activeMainScreen
    }
  }
  LockScreen {
  }
  PolkitDialog {
  }
  Variants {
    model: IdleService.displaysPoweredOff ? [] : WallpaperService.monitors

    AnimatedWallpaper {
      required property var modelData

      monitor: modelData
    }
  }
  LazyLoader {
    active: MainService.ready && WorkspaceService.hasOverview

    component: Variants {
      model: IdleService.displaysPoweredOff ? [] : WallpaperService.monitors

      OverviewWallpaper {
        required property var modelData

        monitor: modelData
      }
    }
  }
}
