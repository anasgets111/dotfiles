import QtQuick
import Quickshell.Io
import qs.Config
import qs.Widgets

Item {
  id: idleInhibitor

  property alias isActive: inhibitorProcess.running

  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemWidth

  Process {
    id: inhibitorProcess

    command: ["sh", "-c", "systemd-inhibit --what=idle --who=Caffeine --why='Caffeine module is active' --mode=block sleep infinity"]
  }
  IconButton {
    id: button

    anchors.fill: parent
    bgColor: inhibitorProcess.running ? Theme.activeColor : Theme.inactiveColor
    iconText: inhibitorProcess.running ? "󰅶" : "󰾪"

    onLeftClicked: inhibitorProcess.running = !inhibitorProcess.running
  }
  Tooltip {
    hAlign: Qt.AlignCenter
    hoverSource: button.area
    target: button
    text: inhibitorProcess.running ? qsTr("Idle inhibition active") : qsTr("Click to prevent idle")
  }
}
