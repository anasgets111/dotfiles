import QtQuick
import Quickshell.Io

Item {
    id: dateTimeDisplay
    property string formattedDateTime: ""
    property string weatherText: ""

    width: textItem.width
    height: Theme.itemHeight

    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var d = new Date();
            dateTimeDisplay.formattedDateTime = Qt.formatDateTime(d, Theme.formatDateTime);
        }
        Component.onCompleted: triggered()
    }

    Weather {
        id: weatherItem
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.itemRadius
        color: Theme.inactiveColor
    }

    Text {
        id: textItem
        anchors.centerIn: parent
        text:   weatherItem.currentTemp + " " + dateTimeDisplay.formattedDateTime
        color: Theme.textContrast(Theme.inactiveColor)
        font.bold: true
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        padding: 8
    }

    MouseArea {
        id: dateTimeMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          swayncProc.running = true;
        }
    }

    Rectangle {
        id: tooltip
        visible: dateTimeMouseArea.containsMouse
        color: Theme.onHoverColor
        radius: Theme.itemRadius
        width: tooltipColumn.implicitWidth + 16
        height: tooltipColumn.implicitHeight + 8
        anchors.top: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 8
        opacity: dateTimeMouseArea.containsMouse ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: tooltipColumn
            anchors.centerIn: parent
            spacing: 2

            Text {
                id: tooltipText
                anchors.horizontalCenter: parent.horizontalCenter
                text: weatherItem.getWeatherDescriptionFromCode()
                color: Theme.textContrast(Theme.onHoverColor)
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: weatherItem.locationName
                color: Theme.textContrast(Theme.onHoverColor)
                font.pixelSize: Theme.fontSize - 2
                font.family: Theme.fontFamily
                visible: weatherItem.locationName.length > 0
            }
        }
    }

    Process {
        id: swayncProc
        command: ["swaync-client", "-t"]
        running: false
    }
}
