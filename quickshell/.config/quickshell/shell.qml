//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma UseQApplication

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

  readonly property bool _netInit: NetworkService.isReady
  readonly property var audio: AudioService
  readonly property var battery: BatteryService
  readonly property var bluetooth: BluetoothService
  readonly property var dateTime: TimeService
  readonly property var ipc: IPC
  readonly property var keyboardLayout: KeyboardLayoutService
  readonly property var lock: LockService
  readonly property var media: MediaService
  readonly property var monitor: MonitorService
  readonly property var network: NetworkService
  // System info services
  readonly property var notifs: NotificationService
  readonly property var osd: OSDService
  readonly property var sysInfo: SystemInfoService
  readonly property var systemTray: SystemTrayService
  readonly property var updater: UpdateService

  // property var main: MainService
  readonly property var wallpaper: WallpaperService
  readonly property var weather: WeatherService
  readonly property var workspaces: WorkspaceService

  Component.onCompleted: {
    // Touch services so they instantiate and log a concise status
    if (root.osd)
      Logger.log("Shell", "OSDService loaded; DND=", root.osd.doNotDisturb);

    if (root.notifs)
      Logger.log("Shell", "NotificationService loaded");
  }

  Bar {
    id: bar
  }

  Binding {
    target: IdleService
    property: "window"
    value: bar
  }

  // Variants {

  //     delegate: Toasts {
  //         modelData: modelData
  //         visible: OSDService.toastVisible
  //     }
  // }
  Loader {
    active: NotificationService.visible && NotificationService.visible.length > 0
    sourceComponent: NotificationPopup {
      modelData: MonitorService ? MonitorService.effectiveMainScreen : null
    }
  }

  // Your wallpapers (unchanged)
  Variants {
    model: root.wallpaper.wallpapersArray

    AnimatedWallpaper {
      modelData: modelData
    }
  }

  // Live clipboard
  Connections {
    target: ClipboardLiteService
  }
  Connections {
    target: IdleService
  }
  LockScreen {}
}
