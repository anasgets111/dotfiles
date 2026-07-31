pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Modules.Bar
import qs.Modules.Bar.Panels
import qs.Modules.Global
import qs.Services.Core
import qs.Services.UI
import qs.Services.Utils

Scope {
  id: root

  required property var modelData

  PanelWindow {
    id: shellWindow

    // One surface and one backdrop-effect request keep the blur kernel continuous where a panel
    // touches the bar. Separate layer-shell surfaces produce visibly different blurred samples.
    readonly property string activeModal: ShellUiState.activeScreenName === screenName ? ShellUiState.activeModal : ""
    readonly property var activeModalItem: modalLoader.item
    readonly property Region chromeBlurRegion: Region {
      regions: shellWindow.activeModalItem?.blurRegion ? [barHost.blurRegion, shellWindow.activeModalItem.blurRegion]
        : panelContainer.blurRegion ? [barHost.blurRegion, panelContainer.blurRegion] : [barHost.blurRegion]
    }
    readonly property bool isPanelActiveHere: ShellUiState.isPanelOpenOn(screenName)
    readonly property string screenName: screen?.name ?? ""

    BackgroundEffect.blurRegion: chromeBlurRegion
    WlrLayershell.exclusionMode: ExclusionMode.Normal
    WlrLayershell.exclusiveZone: Theme.panelHeight
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "obelisk-bar"
    WlrLayershell.keyboardFocus: (panelContainer.active && panelContainer.needsKeyboardFocus) || activeModal !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    // Three anchors retain a top-edge exclusive zone; four anchors would make it ineffective.
    implicitHeight: screen?.height ?? 0
    screen: root.modelData

    mask: Region {
      height: shellWindow.activeModal !== "" || shellWindow.isPanelActiveHere ? shellWindow.height : Theme.panelHeight
      width: shellWindow.width
    }

    Component.onCompleted: IdleService.window = shellWindow

    anchors {
      left: true
      right: true
      top: true
    }
    Bar {
      id: barHost

      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
      }
      screen: shellWindow.screen

      onWallpaperPickerRequested: ShellUiState.openModal("wallpaperPicker", shellWindow.screen?.name ?? "")
    }
    PanelHost {
      id: panelContainer

      active: shellWindow.isPanelActiveHere
      anchorRect: ShellUiState.anchorRect
      anchors.fill: parent
      panelData: ShellUiState.panelData
      panelId: ShellUiState.activePanelId

      onCloseRequested: ShellUiState.closePanel()
    }
    Connections {
      function onLauncherCloseRequested() {
        if (shellWindow.activeModal !== "launcher")
          return;
        const launcher = modalLoader.item as AppLauncher;
        if (launcher)
          launcher.close();
        else
          ShellUiState.closeModal("launcher");
      }

      target: IPC
    }
    Loader {
      id: modalLoader

      active: shellWindow.activeModal !== ""
      anchors.fill: parent
      sourceComponent: ({
          launcher: launcherComponent,
          wallpaperPicker: wallpaperComponent,
          idleSettings: idleComponent,
          kdeconnectSms: kdeConnectSmsComponent
        })[shellWindow.activeModal] ?? null

      onLoaded: item.active = true
    }
    Connections {
      function onDismissed() {
        ShellUiState.closeModal(shellWindow.activeModal);
      }

      target: modalLoader.item
    }
    Component {
      id: launcherComponent

      AppLauncher {
      }
    }
    Component {
      id: wallpaperComponent

      WallpaperPicker {
      }
    }
    Component {
      id: idleComponent

      IdleSettingsPanel {
      }
    }
    Component {
      id: kdeConnectSmsComponent

      KDEConnectSmsModal {
      }
    }
  }
}
