//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma UseQApplication

import QtQml
import QtQuick
import Quickshell
import Quickshell.Wayland
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

  // Variants {

  //     delegate: Toasts {
  //         modelData: modelData
  //         visible: OSDService.toastVisible
  //     }
  // }
  Variants {
    model: Quickshell.screens

    NotificationPopup {
      modelData: modelData
    }
  }

  // Your wallpapers (unchanged)
  Variants {
    model: root.wallpaper.wallpapersArray

    WlrLayershell {
      id: layerShell

      required property var modelData

      anchors.bottom: true
      anchors.left: true
      anchors.right: true
      anchors.top: true
      exclusionMode: ExclusionMode.Ignore
      layer: WlrLayer.Background
      screen: Quickshell.screens.find(s => {
        return s && s.name === layerShell.modelData.name;
      }) || null

      Image {
        anchors.fill: parent
        fillMode: {
          switch (layerShell.modelData.mode) {
          case "fill":
            return Image.PreserveAspectCrop;
          case "fit":
            return Image.PreserveAspectFit;
          case "stretch":
            return Image.Stretch;
          case "center":
            return Image.Pad;
          case "tile":
            return Image.Tile;
          default:
            return Image.PreserveAspectCrop;
          }
        }
        source: layerShell.modelData.wallpaper
      }
    }
  }

  // Live clipboard
  Connections {
    target: ClipboardLiteService
  }
  Connections {
    target: IdleService
  }
  LockScreen {
  }
}
