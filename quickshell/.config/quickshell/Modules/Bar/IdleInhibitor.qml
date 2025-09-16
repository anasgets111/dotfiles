import QtQuick
import qs.Config
import qs.Components
import qs.Services.Core

Item {
  id: caffeineWidget

  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemWidth

  // Local state for our hold
  property bool _caffeineActive: false
  property var _holdTicket: null

  IconButton {
    id: button
    anchors.fill: parent
    bgColor: IdleService.effectiveInhibited ? Theme.activeColor : Theme.inactiveColor
    iconText: caffeineWidget._caffeineActive ? "󰅶" : "󰾪"
    onLeftClicked: {
      if (!caffeineWidget._caffeineActive) {
        caffeineWidget._holdTicket = IdleService.hold("Caffeine widget");
        caffeineWidget._caffeineActive = true;
      } else {
        IdleService.release(caffeineWidget._holdTicket ? caffeineWidget._holdTicket.token : undefined);
        caffeineWidget._holdTicket = null;
        caffeineWidget._caffeineActive = false;
      }
    }
  }

  Tooltip {
    hAlign: Qt.AlignCenter
    hoverSource: button.area
    target: button
    text: (caffeineWidget._caffeineActive ? (qsTr("Idle inhibition active") + "\n" + (MediaService.anyVideoPlaying ? qsTr("Reason: manual + video") : qsTr("Reason: manual"))) : (IdleService.effectiveInhibited ? ((qsTr("Idle inhibition active") + "\n" + (MediaService.anyVideoPlaying ? qsTr("Reason: video") : qsTr("Reason: external")) + "\n" + qsTr("Click to prevent idle"))) : qsTr("Click to prevent idle")))
  }

  // Safety: release on destroy if still active
  Component.onDestruction: {
    if (caffeineWidget._caffeineActive) {
      IdleService.release(caffeineWidget._holdTicket ? caffeineWidget._holdTicket.token : undefined);
    }
  }
}
