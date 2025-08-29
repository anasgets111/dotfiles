import QtQuick
import Quickshell.Io
import qs.Config

Rectangle {
  id: idleInhibitor

  property bool hovered: false
  property string iconOff: "󰾪"
  property string iconOn: "󰅶"
  property alias isActive: inhibitorProcess.running

  color: hovered ? Theme.onHoverColor : (isActive ? Theme.activeColor : Theme.inactiveColor)
  height: Theme.itemHeight
  radius: Theme.itemRadius
  width: Theme.itemWidth

  Process {
    id: inhibitorProcess

    command: ["sh", "-c", "systemd-inhibit --what=idle --who=Caffeine --why='Caffeine module is active' --mode=block sleep infinity"]
  }
  MouseArea {
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: function (mouse) {
      if (mouse.button === Qt.LeftButton) {
        const activating = !inhibitorProcess.running;
        inhibitorProcess.running = activating;
      }
    }
    onEntered: idleInhibitor.hovered = true
    onExited: idleInhibitor.hovered = false
  }
  Text {
    anchors.centerIn: parent
    color: Theme.textContrast(idleInhibitor.hovered ? Theme.onHoverColor : (idleInhibitor.isActive ? Theme.activeColor : Theme.inactiveColor))
    font.bold: true
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: idleInhibitor.isActive ? idleInhibitor.iconOn : idleInhibitor.iconOff
  }
}
