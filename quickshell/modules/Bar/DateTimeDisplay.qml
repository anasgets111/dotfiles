import QtQuick
import QtQuick.Controls
import "."

Item {
    id: dateTimeDisplay
    property string formattedDateTime: ""

    width: textItem.width + 24
    height: Theme.itemHeight

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
        font.pointSize: Theme.fontSize
        font.family: Theme.fontFamily
    }

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
}
