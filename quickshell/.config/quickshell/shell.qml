//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import Quickshell
import qs.Components
import qs.Components
import qs.Modules.Bar
import qs.Modules.Notification
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.SystemInfo
import qs.Services.Utils
import qs.Services.WM

ShellRoot {
  id: root

  readonly property var ipc: IPC
  readonly property var sysInfo: SystemInfoService

  Bar {
    id: bar
  }

  Binding {
    target: IdleService
    property: "window"
    value: bar
  }
  LockScreen {}

  // Variants {

  //     delegate: Toasts {
  //         modelData: modelData
  //         visible: OSDService.toastVisible
  //     }
  // }
  LazyLoader {
    active: NotificationService && NotificationService.visibleNotifications && NotificationService.visibleNotifications.length > 0
    component: NotificationPopup {
      modelData: MonitorService ? MonitorService.effectiveMainScreen : null
    }
  }

  Variants {
    model: WallpaperService.monitors

    LazyLoader {
      id: walLoader
      property var modelData
      loading: WallpaperService.ready && !!modelData && !!modelData.name
      active: WallpaperService.ready && !!modelData && !!modelData.name

      component: AnimatedWallpaper {
        modelData: walLoader.modelData
        // inside AnimatedWallpaper, ensure:
        // Image { asynchronous: true; cache: true; source: hasRealSize ? currentSrc : "" }
      }
    }
  }

  // Live clipboard
  // Connections {
  //   target: ClipboardLiteService
  // }
}
