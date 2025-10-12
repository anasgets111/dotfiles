//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import Quickshell
import qs.Components
import qs.Modules.Bar
import qs.Modules.OSD
import qs.Modules.AppLauncher
import qs.Modules.WallpaperPicker
import qs.Modules.Notification
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

    active: OSDService.visible

    component: OSDOverlay {
      modelData: MonitorService ? MonitorService.effectiveMainScreen : null
    }
  }

  // Global App Launcher loader controlled by IPC
  LazyLoader {
    id: launcherLoader

    active: root.ipc.launcherActive && !bar.centerShouldHide

    component: Launcher {
      Component.onCompleted: open()
      onDismissed: root.ipc.launcherActive = false
    }
  }

  LazyLoader {
    id: wallpaperPickerLoader

    active: root.wallpaperPickerActive

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
    active: NotificationService?.visibleNotifications?.length > 0
    activeAsync: true

    component: NotificationPopup {
      modelData: MonitorService ? MonitorService.effectiveMainScreen : null
    }
  }

  Variants {
    model: WallpaperService.monitors

    AnimatedWallpaper {
      modelData: modelData
    }
  }
}
