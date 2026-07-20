pragma ComponentBehavior: Bound
import Quickshell
import qs.Components
import qs.Services.SystemInfo
import qs.Config

OPopup {
  id: root

  blurRegion: Region {
    height: Math.max(0, card.height - 4)
    radius: Theme.radiusXl
    width: Math.max(0, card.width - 4)
    x: card.x + 2
    y: card.y + 2
  }
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
