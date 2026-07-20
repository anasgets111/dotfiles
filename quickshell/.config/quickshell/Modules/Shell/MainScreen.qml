pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Components
import qs.Config
import qs.Modules.Bar
import qs.Modules.Bar.Panels
import qs.Modules.Global
import qs.Services.Core
import qs.Services.UI

Scope {
  id: root

  required property var modelData
  readonly property bool overlayRequested: ShellUiState.isAnyInteractiveOpen
  property bool overlayRetained: false

  onOverlayRequestedChanged: {
    if (overlayRequested) {
      overlayDestroyTimer.stop();
      overlayRetained = true;
    } else if (overlayRetained) {
      overlayDestroyTimer.restart();
    }
  }

  Component.onCompleted: overlayRetained = overlayRequested

  Timer {
    id: overlayDestroyTimer

    interval: Theme.animationDuration

    onTriggered: if (!root.overlayRequested)
      root.overlayRetained = false
  }
  PanelWindow {
    id: barWindow

    BackgroundEffect.blurRegion: barHost.blurRegion
    WlrLayershell.exclusionMode: ExclusionMode.Normal
    WlrLayershell.exclusiveZone: Theme.panelHeight
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "obelisk-bar"
    color: "transparent"
    implicitHeight: barHost.implicitHeight
    screen: root.modelData

    mask: Region {
      height: Theme.panelHeight
      width: barWindow.width
    }

    Component.onCompleted: IdleService.window = barWindow

    anchors {
      left: true
      right: true
      top: true
    }
    Bar {
      id: barHost

      anchors.fill: parent
      screen: barWindow.screen

      onWallpaperPickerRequested: ShellUiState.openModal("wallpaperPicker", barWindow.screen?.name ?? "")
    }
  }
  LazyLoader {
    active: root.overlayRetained

    component: PanelWindow {
      id: overlayWindow

      readonly property string activeModal: ShellUiState.activeScreenName === screenName ? ShellUiState.activeModal : ""
      readonly property bool isPanelActiveHere: ShellUiState.isPanelOpenOn(screenName)
      readonly property string screenName: screen?.name ?? ""

      BackgroundEffect.blurRegion: {
        switch (overlayWindow.activeModal) {
        case "launcher":
          return launcherLoader.item?.blurRegion ?? null;
        case "wallpaperPicker":
          return wallpaperLoader.item?.blurRegion ?? null;
        case "idleSettings":
          return idleLoader.item?.blurRegion ?? null;
        }
        return panelContainer.blurRegion;
      }
      WlrLayershell.exclusionMode: ExclusionMode.Ignore
      WlrLayershell.keyboardFocus: (panelContainer.active && panelContainer.needsKeyboardFocus) || activeModal !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.namespace: "obelisk-overlay"
      color: "transparent"
      screen: root.modelData

      mask: Region {
        height: overlayWindow.activeModal !== "" ? overlayWindow.height : overlayWindow.isPanelActiveHere ? Math.max(0, overlayWindow.height - Theme.panelHeight) : 0
        width: overlayWindow.width
        y: overlayWindow.isPanelActiveHere ? Theme.panelHeight : 0
      }

      anchors {
        bottom: true
        left: true
        right: true
        top: true
      }
      OPanel {
        id: panelContainer

        active: overlayWindow.isPanelActiveHere
        anchorRect: ShellUiState.anchorRect
        anchors.fill: parent
        panelData: ShellUiState.panelData
        panelId: ShellUiState.activePanelId

        onCloseRequested: ShellUiState.closePanel()
      }
      Loader {
        id: launcherLoader

        active: overlayWindow.activeModal === "launcher"
        anchors.fill: parent

        sourceComponent: AppLauncher {
          active: true

          onDismissed: ShellUiState.closeModal("launcher")
        }
      }
      Loader {
        id: wallpaperLoader

        active: overlayWindow.activeModal === "wallpaperPicker"
        anchors.fill: parent

        sourceComponent: WallpaperPicker {
          active: true

          onApplyRequested: ShellUiState.closeModal("wallpaperPicker")
          onCancelRequested: ShellUiState.closeModal("wallpaperPicker")
          onDismissed: ShellUiState.closeModal("wallpaperPicker")
        }
      }
      Loader {
        id: idleLoader

        active: overlayWindow.activeModal === "idleSettings"
        anchors.fill: parent

        sourceComponent: IdleSettingsPanel {
          active: true

          onDismissed: ShellUiState.closeModal("idleSettings")
        }
      }
    }
  }
}
