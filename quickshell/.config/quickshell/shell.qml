//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1

pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import Quickshell
import qs.Modules.Bar
import qs.Modules.Global
import qs.Modules.Notification
import qs.Modules.OSD
import qs.Services
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.Utils
import qs.Services.WM

ShellRoot {
  id: root

  readonly property var ipc: IPC
  readonly property var sysInfo: SystemInfoService
  property bool wallpaperPickerActive: false

  Bar {
    id: bar

    onWallpaperPickerRequested: root.wallpaperPickerActive = true
  }

  LazyLoader {
    id: osdLoader

    activeAsync: OSDService.visible

    component: OSDOverlay {
      modelData: MonitorService ? MonitorService.effectiveMainScreen : null
    }
  }

  // Global App Launcher loader controlled by IPC
  LazyLoader {
    id: launcherLoader

    activeAsync: root.ipc.launcherActive && !bar.centerShouldHide

    component: AppLauncher {
      Component.onCompleted: open()
      onDismissed: root.ipc.launcherActive = false
    }
  }

  LazyLoader {
    id: wallpaperPickerLoader

    activeAsync: root.wallpaperPickerActive

    component: WallpaperPicker {
      Component.onCompleted: open()
      onCancelRequested: root.wallpaperPickerActive = false
      onDismissed: root.wallpaperPickerActive = false
    }
  }

  Binding {
    property: "window"
    target: IdleService
    value: bar
  }

  LockScreen {
  }

  LazyLoader {
    activeAsync: NotificationService?.visibleNotifications?.length > 0

    component: NotificationPopup {
      modelData: MonitorService ? MonitorService.effectiveMainScreen : null
    }
  }

  PolkitDialog {
  }

  Variants {
    model: WallpaperService.monitors

    AnimatedWallpaper {
      required property var modelData

      monitor: modelData
    }
  }

  // Niri overview wallpaper - static, shown only in overview via layer-rule
  LazyLoader {
    activeAsync: MainService.ready && MainService.currentWM === "niri"

    component: Variants {
      model: WallpaperService.monitors

      OverviewWallpaper {
        required property var modelData

        monitor: modelData
      }
    }
  }
}
