import QtQuick
import Quickshell.Wayland
import qs.Components
import qs.Config
import qs.Services.Core

Item {
  id: caffeineWidget

  property bool _caffeineActive: false

  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemWidth
  Component.onDestruction: {
    caffeineWidget._caffeineActive = false;
  }

  IconButton {
    id: button

    anchors.fill: parent
    colorBg: (caffeineWidget._caffeineActive || IdleService.effectiveInhibited) ? Theme.activeColor : Theme.inactiveColor
    icon: caffeineWidget._caffeineActive ? "󰅶" : "󰾪"
    tooltipText: (caffeineWidget._caffeineActive ? (qsTr("Idle inhibition active") + "\n" + (MediaService.anyVideoPlaying ? qsTr("Reason: manual + video") : qsTr("Reason: manual"))) : (IdleService.effectiveInhibited ? (qsTr("Idle inhibition active") + "\n" + (MediaService.anyVideoPlaying ? qsTr("Reason: video") : qsTr("Reason: external")) + "\n" + qsTr("Click to prevent idle")) : qsTr("Click to prevent idle")))
    onClicked: caffeineWidget._caffeineActive = !caffeineWidget._caffeineActive
  }

  IdleInhibitor {
    enabled: caffeineWidget._caffeineActive
    window: IdleService.window
  }
}
