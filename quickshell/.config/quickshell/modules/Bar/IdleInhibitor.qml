import QtQuick
import Quickshell.Io

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

    command: ["systemd-inhibit", "--what=idle:sleep", "--who=quickshell", "--why=User inhibited idle", "sleep", "infinity"]
  }
  Process {
    id: lockProcess

    command: ["hyprlock"]
  }
  Process {
    id: pauseHypridle

    command: ["sh", "-c", "pidof hypridle >/dev/null 2>&1 && kill -STOP $(pidof hypridle) || true"]
  }
  Process {
    id: resumeHypridle

    command: ["sh", "-c", "pidof hypridle >/dev/null 2>&1 && kill -CONT $(pidof hypridle) || true"]
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
        if (activating) {
          pauseHypridle.running = true;
        } else {
          resumeHypridle.running = true;
        }
      } else if (mouse.button === Qt.RightButton) {
        lockProcess.running = true;
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
