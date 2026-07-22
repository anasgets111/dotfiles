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

  readonly property var ipc: IPC
  readonly property var sysInfo: SystemInfoService

  MainScreen {
    modelData: MonitorService.effectiveMainScreen
  }
  LazyLoader {
    active: NotificationService.visibleNotifications.length > 0

    component: NotificationPopup {
      modelData: MonitorService.effectiveMainScreen
    }
  }
  LazyLoader {
    active: OSDService.visible

    component: OSDPopup {
      modelData: MonitorService.effectiveMainScreen
    }
  }
  LazyLoader {
    // Settings load after QML defaults; synchronous activation avoids an activeAsync cancellation race.
    active: InputDisplayService.enabled

    component: InputDisplayPopup {
      modelData: MonitorService.effectiveMainScreen
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
