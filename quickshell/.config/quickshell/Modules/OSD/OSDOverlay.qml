pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.SystemInfo
import qs.Config

PanelWindow {
  required property var modelData

  WlrLayershell.exclusiveZone: -1
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.layer: WlrLayer.Overlay
  color: "transparent"
  screen: modelData
  visible: OSDService.visible

  mask: Region {
    item: card
  }

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }

  OSDCard {
    id: card

    icon: OSDService.osdIcon
    label: OSDService.osdLabel
    maxValue: OSDService.osdMaxValue
    showing: OSDService.visible
    value: OSDService.osdValue

    anchors {
      bottom: parent.bottom
      bottomMargin: Theme.popupOffset * 11
      horizontalCenter: parent.horizontalCenter
    }
  }
}
