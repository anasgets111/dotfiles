import QtQuick
import QtQuick.Controls
import "." as BarTheme

Item {
    id: dateTimeDisplay
    property string formattedDateTime: ""

    width: textItem.width + 24
    height: textItem.height + 12

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.inactiveColor
        border.color: Theme.barBorder

    }

    Text {
        id: textItem
        anchors.centerIn: parent
        text: dateTimeDisplay.formattedDateTime
        color: Theme.textInactiveColor
        font.bold: true
        font.pointSize: Theme.barFontSize
        font.family: Theme.barFontFamily
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
