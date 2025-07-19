import QtQuick
import Quickshell.Io

Item {
    id: dateTimeDisplay
    property string formattedDateTime: ""

    width: textItem.width
    height: Theme.itemHeight

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var d = new Date();
            dateTimeDisplay.formattedDateTime = Qt.formatDateTime(d, Theme.formatDateTime);
        }
        Component.onCompleted: triggered()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.itemRadius
        color: Theme.inactiveColor
    }

    Text {
        id: textItem
        anchors.centerIn: parent
        text: dateTimeDisplay.formattedDateTime
        color: Theme.textContrast(Theme.inactiveColor)
        font.bold: true
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        padding: 8
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: swayncProc.running = true
    }

    Process {
        id: swayncProc
        command: ["swaync-client", "-t"]
        running: false
        // Optionally handle output:
        // stdout: StdioCollector { onStreamFinished: { /* handle output if needed */ } }
    }
}
