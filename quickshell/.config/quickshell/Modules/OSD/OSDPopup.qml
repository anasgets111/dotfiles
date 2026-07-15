pragma ComponentBehavior: Bound
import qs.Components
import qs.Services.SystemInfo
import qs.Config

OPopup {
  maskItem: card
  popupNamespace: "obelisk-osd-overlay"
  visible: OSDService.visible

  OSDCard {
    id: card

    icon: OSDService.osdIcon
    label: OSDService.osdLabel
    maxValue: OSDService.osdMaxValue
    showing: OSDService.visible
    type: OSDService.osdType
    value: OSDService.osdValue

    anchors {
      bottom: parent.bottom
      bottomMargin: Theme.popupOffset * 11
      horizontalCenter: parent.horizontalCenter
    }
  }
}
