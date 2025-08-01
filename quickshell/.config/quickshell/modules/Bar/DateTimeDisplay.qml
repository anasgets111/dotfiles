import QtQuick
import Quickshell.Io

Item {
    id: dateTimeDisplay

    property string formattedDateTime: ""
    property string weatherText: ""
    property var currentDate: new Date()

    width: textItem.width
    height: Theme.itemHeight

    Timer {
        id: clockTimer

        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var d = new Date();
            dateTimeDisplay.currentDate = d;
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
        text: weatherItem.currentTemp + " " + dateTimeDisplay.formattedDateTime
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

    // Tooltip background and content: Rectangle is now parent of Column
    Item {
        id: tooltip

        visible: dateTimeMouseArea.containsMouse
        anchors.top: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 8
        opacity: dateTimeMouseArea.containsMouse ? 1 : 0
        width: tooltipColumn.width + 16
        height: tooltipColumn.implicitHeight + 8

        Rectangle {
            anchors.fill: parent
            color: Theme.onHoverColor
            radius: Theme.itemRadius
            z: -1
        }

        Column {
            id: tooltipColumn

            property real widest: Math.max(firstRow.width, calendar.width)

            anchors.centerIn: parent
            spacing: 6
            width: widest

            // First row: description and place
            Row {
                id: firstRow

                spacing: 8
                anchors.horizontalCenter: parent.horizontalCenter
                width: implicitWidth

                Text {
                    id: tooltipText

                    text: weatherItem.getWeatherDescriptionFromCode()
                    color: Theme.textContrast(Theme.onHoverColor)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                }

                Text {
                    text: "in " + weatherItem.locationName
                    color: Theme.textContrast(Theme.onHoverColor)
                    font.pixelSize: Theme.fontSize - 2
                    font.family: Theme.fontFamily
                    visible: weatherItem.locationName.length > 0
                }
            }

            // Second row: extracted MinimalCalendar component
            MinimalCalendar {
                id: calendar

                theme: Theme
                weekStart: 6
                today: dateTimeDisplay.currentDate
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animationDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    Process {
        id: swayncProc

        command: ["swaync-client", "-t"]
        running: false
    }
}
