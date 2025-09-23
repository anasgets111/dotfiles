import QtQuick
import Quickshell.Wayland
import qs.Config
import qs.Components
import qs.Services
import qs.Services.Core

Item {
  id: caffeineWidget

  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemWidth

  // Local state for manual inhibition
  property bool _caffeineActive: false

  IconButton {
    id: button
    anchors.fill: parent
    bgColor: (caffeineWidget._caffeineActive || IdleService.effectiveInhibited) ? Theme.activeColor : Theme.inactiveColor
    iconText: caffeineWidget._caffeineActive ? "󰅶" : "󰾪"
    onLeftClicked: {
      caffeineWidget._caffeineActive = !caffeineWidget._caffeineActive;
    }
  }

  IdleInhibitor {
    enabled: caffeineWidget._caffeineActive
    window: IdleService.window
  }

  Tooltip {
    hAlign: Qt.AlignCenter
    hoverSource: button.area
    target: button
    text: (caffeineWidget._caffeineActive ? (qsTr("Idle inhibition active") + "\n" + (MediaService.anyVideoPlaying ? qsTr("Reason: manual + video") : qsTr("Reason: manual"))) : (IdleService.effectiveInhibited ? ((qsTr("Idle inhibition active") + "\n" + (MediaService.anyVideoPlaying ? qsTr("Reason: video") : qsTr("Reason: external")) + "\n" + qsTr("Click to prevent idle"))) : qsTr("Click to prevent idle")))
  }

  // Safety: disable on destroy if still active
  Component.onDestruction: {
    caffeineWidget._caffeineActive = false;
  }
}
