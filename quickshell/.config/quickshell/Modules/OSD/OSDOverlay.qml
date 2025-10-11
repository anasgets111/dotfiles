pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.SystemInfo
import qs.Config

PanelWindow {
  required property var modelData

  color: "transparent"
  screen: modelData
  visible: OSDService.visible

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.exclusiveZone: -1

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  mask: Region {
    item: card
  }

  OSDCard {
    id: card
    anchors {
      bottom: parent.bottom
      horizontalCenter: parent.horizontalCenter
      bottomMargin: Theme.popupOffset * 11
    }

    icon: OSDService.osdIcon
    label: OSDService.osdLabel
    value: OSDService.osdValue
    showing: OSDService.visible
  }
}
