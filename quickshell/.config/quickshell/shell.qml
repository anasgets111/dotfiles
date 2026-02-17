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

  OSDOverlay {
    modelData: MonitorService.effectiveMainScreen
  }

  LockScreen {
  }

  PolkitDialog {
  }

  Connections {
    function onActiveModalChanged() {
      const launcherOpen = ShellUiState.activeModal === "launcher";
      if (!launcherOpen && root.ipc.launcherActive)
        root.ipc.launcherActive = false;
      if (launcherOpen && !root.ipc.launcherActive)
        root.ipc.launcherActive = true;
    }

    target: ShellUiState
  }

  Connections {
    function onLauncherActiveChanged() {
      if (root.ipc.launcherActive) {
        ShellUiState.openModal("launcher", MonitorService.effectiveMainScreen?.name ?? "");
      } else if (ShellUiState.activeModal === "launcher") {
        ShellUiState.closeModal("launcher");
      }
    }

    target: root.ipc
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
