import QtQuick
import Quickshell.Wayland
import qs.Config
import qs.Components
import qs.Services.Core

Item {
  id: caffeineWidget

  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemWidth

  property bool _caffeineActive: false

  IconButton {
    id: button
    anchors.fill: parent
    colorBg: (caffeineWidget._caffeineActive || IdleService.effectiveInhibited) ? Theme.activeColor : Theme.inactiveColor
    icon: caffeineWidget._caffeineActive ? "󰅶" : "󰾪"
    tooltipText: (caffeineWidget._caffeineActive ? (qsTr("Idle inhibition active") + "\n" + (MediaService.anyVideoPlaying ? qsTr("Reason: manual + video") : qsTr("Reason: manual"))) : (IdleService.effectiveInhibited ? (qsTr("Idle inhibition active") + "\n" + (MediaService.anyVideoPlaying ? qsTr("Reason: video") : qsTr("Reason: external")) + "\n" + qsTr("Click to prevent idle")) : qsTr("Click to prevent idle")))
    onLeftClicked: caffeineWidget._caffeineActive = !caffeineWidget._caffeineActive
  }

  IdleInhibitor {
    enabled: caffeineWidget._caffeineActive
    window: IdleService.window
  }

  Component.onDestruction: {
    caffeineWidget._caffeineActive = false;
  }
}
