import QtQuick
import Quickshell.Io
import qs.Config
import qs.Widgets

Item {
  id: idleInhibitor

  property string iconOff: "󰾪"
  property string iconOn: "󰅶"
  property alias isActive: inhibitorProcess.running

  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemWidth

  Process {
    id: inhibitorProcess

    command: ["sh", "-c", "systemd-inhibit --what=idle --who=Caffeine --why='Caffeine module is active' --mode=block sleep infinity"]
  }
  IconButton {
    id: iconButton

    anchors.centerIn: parent
    iconText: idleInhibitor.isActive ? idleInhibitor.iconOn : idleInhibitor.iconOff

    onClicked: {
      inhibitorProcess.running = !inhibitorProcess.running;
    }
  }
  Tooltip {
    hoverSource: iconButton.area
    target: iconButton
    text: idleInhibitor.isActive ? "Idle inhibitor: Active" : "Idle inhibitor: Inactive"
  }
}
