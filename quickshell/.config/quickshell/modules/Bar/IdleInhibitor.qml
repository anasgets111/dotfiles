import QtQuick
import Quickshell.Io

Rectangle {
    id: idleInhibitor

    property string iconOn: "󰅶"
    property string iconOff: "󰾪"
    property bool hovered: false
    property alias isActive: inhibitorProcess.running

    width: Theme.itemWidth
    height: Theme.itemHeight
    radius: Theme.itemRadius
    color: hovered ? Theme.onHoverColor : (isActive ? Theme.activeColor : Theme.inactiveColor)

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
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
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
        text: idleInhibitor.isActive ? idleInhibitor.iconOn : idleInhibitor.iconOff
        color: Theme.textContrast(idleInhibitor.hovered ? Theme.onHoverColor : (idleInhibitor.isActive ? Theme.activeColor : Theme.inactiveColor))
        font.pixelSize: Theme.fontSize
        font.bold: true
        font.family: Theme.fontFamily
    }
}
