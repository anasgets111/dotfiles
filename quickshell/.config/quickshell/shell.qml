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
import qs.Services.UI
import qs.Services.Utils
import qs.Services.WM

ShellRoot {
  id: root

  readonly property var ipc: IPC
  readonly property var sysInfo: SystemInfoService

  MainScreen {
    modelData: MonitorService.effectiveMainScreen
  }
  NotificationPopup {
    modelData: MonitorService.effectiveMainScreen
  }
  OSDPopup {
    modelData: MonitorService.effectiveMainScreen
  }
  LazyLoader {
    // Settings load after the QML defaults. Synchronous activation avoids an
    // activeAsync cancellation race leaving the default-enabled surface alive.
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

  // Niri overview wallpaper - static, shown only in overview via layer-rule
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
