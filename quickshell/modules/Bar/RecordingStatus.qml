import QtQuick
import QtQuick.Controls
import Quickshell.Io

// RecordingStatus.qml
// Widget to poll a script for recording status and display it, with click-to-toggle

Item {
    id: root
    width: Theme.itemWidth
    height: Theme.itemHeight
    visible: statusText !== ""

    property string statusText: ""
    property bool isRecording: false

    // --- Timer to poll the script every 2 seconds ---
    Timer {
        id: pollTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            statusProcess.running = true

        }
    }

    // --- Use Quickshell.Io.Process for polling script, with StdioCollector for stdout ---
    Process {
        id: statusProcess
        command: ["/home/anas/.local/bin/RecordingStatus.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("RecordingStatus script output:", this.text)
                try {
                    var json = JSON.parse(this.text)
                    console.log("RecordingStatus parsed JSON:", JSON.stringify(json))
                    root.statusText = json.text || ""
                    root.isRecording = json.isRecording || false
                } catch (e) {
                    console.log("RecordingStatus parse error:", e)
                    root.statusText = ""
                    root.isRecording = false
                }
            }
        }
    }

    // --- Click to toggle recording ---
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

    // --- Visuals: styled circle if recording, text in center ---
    Rectangle {
        anchors.fill: parent
        color: root.isRecording
            ? Theme.activeColor
            : (root.hovered ? Theme.onHoverColor : Theme.inactiveColor)
        radius: Theme.itemRadius
        border.color: Theme.borderColor
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: root.statusText
            color: Theme.textContrast(
                root.isRecording
                    ? Theme.activeColor
                    : (root.hovered ? Theme.onHoverColor : Theme.inactiveColor)
            )
            font.bold: true
            font.pixelSize: Theme.fontSize
            font.family: Theme.fontFamily
        }
    }

    property bool hovered: false
}
