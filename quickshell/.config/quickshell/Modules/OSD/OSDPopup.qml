pragma ComponentBehavior: Bound
import Quickshell
import qs.Components
import qs.Config
import qs.Services.SystemInfo

OPopup {
  blurRegion: Region {
    item: card
    radius: Theme.radiusLg
  }
  maskItem: card
  popupNamespace: "obelisk-osd-overlay"
  visible: OSDService.visible

  OSDCard {
    id: card

    icon: OSDService.osdIcon
    label: OSDService.osdLabel
    showing: OSDService.visible
    type: OSDService.osdType
    value: OSDService.osdValue

    anchors {
      bottom: parent.bottom
      bottomMargin: Theme.osdBottomMargin
      horizontalCenter: parent.horizontalCenter
    }
  }
}
