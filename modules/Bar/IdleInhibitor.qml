import QtQuick 2.15
import Quickshell
import Quickshell.Io
import "."

Rectangle {
  id: idleInhibitor
  width: Theme.itemWidth
  height: Theme.itemHeight
  radius: Theme.itemRadius

  /* style constants */
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
  color: isActive ? Theme.activeColor : Theme.inactiveColor
  border.color: Theme.borderColor
  border.width: Theme.borderWidth

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
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
    color: isActive ? Theme.textActiveColor : Theme.textInactiveColor
    font.pixelSize: Theme.fontSize
    font.bold : true
    font.family: Theme.fontFamily
  }
}
