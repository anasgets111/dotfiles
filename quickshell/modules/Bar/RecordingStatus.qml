import QtQuick
import QtQuick.Controls
import Quickshell.Io

Item {
    id: root

    property string statusText: ""
    property bool isRecording: false
    property bool hovered: false

    width: Theme.itemWidth
    height: Theme.itemHeight
    visible: statusText !== ""

    Timer {
        id: pollTimer

        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            statusProcess.running = true;
        }
    }

    Process {
        id: statusProcess

        command: ["/home/anas/.local/bin/RecordingStatus.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var json = JSON.parse(this.text);
                    root.statusText = json.text || "";
                    root.isRecording = json.isRecording || false;
                } catch (e) {
                    root.statusText = "";
                    root.isRecording = false;
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: {
            var toggleProcess = Qt.createQmlObject('import Quickshell.Io 1.0; Process {}', root);
            toggleProcess.command = ["sh", "/home/anas/.local/bin/ScreenRecording.sh"];
            toggleProcess.running = true;
        }
        cursorShape: Qt.PointingHandCursor
    }

    Rectangle {
        anchors.fill: parent
        color: root.isRecording ? Theme.activeColor : (root.hovered ? Theme.onHoverColor : Theme.inactiveColor)
        radius: Theme.itemRadius
        border.color: Theme.borderColor
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: root.statusText
            color: Theme.textContrast(root.isRecording ? Theme.activeColor : (root.hovered ? Theme.onHoverColor : Theme.inactiveColor))
            font.bold: true
            font.pixelSize: Theme.fontSize
            font.family: Theme.fontFamily
        }
    }
}
