import QtQuick
import Quickshell.Io

Rectangle {
    id: idleInhibitor

    property string iconOn: ""
    property string iconOff: ""
    property bool hovered: false
    property alias isActive: inhibitorProcess.running

    width: Theme.itemWidth
    height: Theme.itemHeight
    radius: Theme.itemRadius
    color: hovered ? Theme.onHoverColor : (isActive ? Theme.activeColor : Theme.inactiveColor)

    Process {
        id: inhibitorProcess

        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=User inhibited idle", "sleep", "infinity"]
    }

    Process {
        id: lockProcess

        command: ["hyprlock"]
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: function (mouse) {
            if (mouse.button === Qt.LeftButton)
                inhibitorProcess.running = !inhibitorProcess.running;
            else if (mouse.button === Qt.RightButton)
                lockProcess.running = true;
        }
        onEntered: idleInhibitor.hovered = true
        onExited: idleInhibitor.hovered = false
    }

    Text {
        anchors.centerIn: parent
        text: isActive ? iconOn : iconOff
        color: Theme.textContrast(hovered ? Theme.onHoverColor : (isActive ? Theme.activeColor : Theme.inactiveColor))
        font.pixelSize: Theme.fontSize
        font.bold: true
        font.family: Theme.fontFamily
    }
}
