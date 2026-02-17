pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Components
import qs.Config
import qs.Modules.Bar
import qs.Modules.Bar.Panels
import qs.Modules.Global
import qs.Services
import qs.Services.Core
import qs.Services.UI

PanelWindow {
  id: root

  readonly property bool hasInteractiveHere: ShellUiState.activeScreenName === root.screenName && ShellUiState.isAnyInteractiveOpen
  readonly property bool isModalActiveHere: ShellUiState.activeScreenName === root.screenName && ShellUiState.isAnyModalOpen
  readonly property bool isPanelActiveHere: ShellUiState.isPanelOpenOn(root.screenName)
  readonly property bool isWallpaperPickerOpen: ShellUiState.isModalOpenOn(root.screenName, "wallpaperPicker")
  readonly property bool isIdleSettingsOpen: ShellUiState.isModalOpenOn(root.screenName, "idleSettings")
  readonly property bool launcherOpen: ShellUiState.isModalOpenOn(root.screenName, "launcher")
  property var modelData: null
  readonly property bool panelNeedsKeyboardFocus: panelContainer.active && panelContainer.needsKeyboardFocus
  readonly property string screenName: screen?.name ?? ""
  readonly property bool shouldCaptureBackground: ShellUiState.isAnyPanelOpen || ShellUiState.isAnyModalOpen
  readonly property bool wantsKeyboardHere: panelNeedsKeyboardFocus || launcherOpen || isWallpaperPickerOpen || isIdleSettingsOpen

  WlrLayershell.exclusionMode: ExclusionMode.Normal
  WlrLayershell.exclusiveZone: Theme.panelHeight
  WlrLayershell.keyboardFocus: {
    if (!ShellUiState.isAnyInteractiveOpen)
      return WlrKeyboardFocus.None;

    if (root.hasInteractiveHere) {
      if (MainService.currentWM === "hyprland")
        return ShellUiState.isInitializingKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand;
      return root.wantsKeyboardHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand;
    }

    return WlrKeyboardFocus.OnDemand;
  }
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "obelisk-main-screen-" + (root.screenName || "unknown")
  color: "transparent"
  implicitHeight: screen ? screen.height : Theme.panelHeight
  screen: root.modelData
  surfaceFormat.opaque: false

  mask: Region {
    height: root.height
    intersection: Intersection.Xor
    regions: [barMaskRegion, backgroundMaskRegion]
    width: root.width
    x: 0
    y: 0

    Region {
      id: barMaskRegion

      intersection: Intersection.Subtract
      item: barClickableRegion
    }

    Region {
      id: backgroundMaskRegion

      height: root.shouldCaptureBackground ? root.height : 0
      intersection: Intersection.Subtract
      width: root.shouldCaptureBackground ? root.width : 0
      x: 0
      y: 0
    }
  }

  Component.onCompleted: IdleService.window = root

  anchors {
    left: true
    right: true
    top: true
  }

  Item {
    anchors.fill: parent

    MouseArea {
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      anchors.fill: parent
      enabled: root.shouldCaptureBackground && !root.isPanelActiveHere && !root.isModalActiveHere

      onClicked: {
        ShellUiState.closePanel();
        ShellUiState.closeModal();
      }
    }

    Item {
      id: barClickableRegion

      height: barHost.height
      width: root.width
      z: 10

      Bar {
        id: barHost

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        screen: root.screen

        onWallpaperPickerRequested: ShellUiState.openModal("wallpaperPicker", root.screenName)
      }
    }

    OPanel {
      id: panelContainer

      active: root.isPanelActiveHere
      anchorRect: ShellUiState.anchorRect
      anchors.fill: parent
      panelData: ShellUiState.panelData
      panelId: ShellUiState.activePanelId
      z: 60

      onCloseRequested: ShellUiState.closePanel()
    }

    Loader {
      active: root.launcherOpen
      anchors.fill: parent
      z: 70

      sourceComponent: AppLauncher {
        active: true

        onDismissed: ShellUiState.closeModal("launcher")
      }
    }

    Loader {
      active: root.isWallpaperPickerOpen
      anchors.fill: parent
      z: 75

      sourceComponent: WallpaperPicker {
        active: true

        onApplyRequested: ShellUiState.closeModal("wallpaperPicker")
        onCancelRequested: ShellUiState.closeModal("wallpaperPicker")
        onDismissed: ShellUiState.closeModal("wallpaperPicker")
      }
    }

    Loader {
      active: root.isIdleSettingsOpen
      anchors.fill: parent
      z: 75

      sourceComponent: IdleSettingsPanel {
        active: true

        onDismissed: ShellUiState.closeModal("idleSettings")
      }
    }
  }
}
