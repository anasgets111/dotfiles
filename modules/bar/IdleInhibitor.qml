import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: idleInhibitor

    width: 32
    height: 24
    radius: 15
    color: isActive ? "#4a9eff" : "#333333"
    border.color: "#555555"
    border.width: 2

    property bool isActive: false

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                toggleIdleInhibitor()
            } else if (mouse.button === Qt.RightButton) {
                lockScreen()
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: isActive ? "" : ""
        color: isActive ? "#1a1a1a" : "#cccccc"
        font.pixelSize: 14
        font.family: parent.parent.fontFamily
    }

    Process {
        id: inhibitorProcess
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=User inhibited idle", "sleep", "infinity"]

        onStarted: isActive = true
        onExited: isActive = false
    }

    Process {
        id: lockProcess
        command: ["hyprlock"]
    }

    function toggleIdleInhibitor() {
        if (isActive) {
            inhibitorProcess.running = false
        } else {
            inhibitorProcess.running = true
        }
    }

    function lockScreen() {
        lockProcess.running = true
    }
}
