import QtQuick 2.15
import Quickshell
import Quickshell.Io

Rectangle {
  id: idleInhibitor
  width: 32; height: 24; radius: 7

  /* style constants */
  property color activeBg:   "#4a9eff"
  property color inactiveBg: "#333333"
  property color borderCol:  "#555555"
  property color textActive:   "#1a1a1a"
  property color textInactive: "#cccccc"
  property string iconOn:  ""
  property string iconOff: ""

  /* bind state directly to process.running */
  Process {
    id: inhibitorProcess
    command: [
      "systemd-inhibit",
      "--what=idle",
      "--who=quickshell",
      "--why=User inhibited idle",
      "sleep", "infinity"
    ]
  }
  property alias isActive: inhibitorProcess.running

  /* lock screen process */
  Process { id: lockProcess; command: ["hyprlock"] }

  /* dynamic styling */
  color: isActive ? activeBg : inactiveBg
  border.color: borderCol; border.width: 2

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: {
      if (mouse.button === Qt.LeftButton) {
        inhibitorProcess.running = !inhibitorProcess.running
      } else if (mouse.button === Qt.RightButton) {
        lockProcess.running = true
      }
    }
  }

  Text {
    anchors.centerIn: parent
    text: isActive ? iconOn : iconOff
    color: isActive ? textActive : textInactive
    font.pixelSize: 14
    font.family: panel.fontFamily
  }
}
