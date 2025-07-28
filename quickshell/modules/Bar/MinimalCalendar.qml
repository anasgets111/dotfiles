import QtQuick

Item {
    id: calendarGrid

    // Cell and layout constants
    property int cellWidth: 32
    property int cellHeight: 22
    property int headerHeight: 22
    property int titleHeight: 22
    property int spacing: 8

    // Calendar calculations
    property var today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()
    property int daysInMonth: (new Date(year, month + 1, 0)).getDate()
    property int firstDay: (new Date(year, month, 1)).getDay()
    property var weekDays: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    // Expose theme properties for parent to set if needed
    property var theme: null

    // Calculate number of rows needed for the month grid
    property int rowCount: Math.ceil((firstDay + daysInMonth) / 7)

    // Dynamic sizing
    implicitWidth: (7 * cellWidth) + (6 * spacing)
    implicitHeight: titleHeight + headerHeight + (rowCount * cellHeight) + ((rowCount - 1) * spacing) + (2 * spacing)

   // weekStart: 0=Sunday, 1=Monday, ..., 6=Saturday
   property int weekStart: 0

    Column {
        spacing: calendarGrid.spacing
        anchors.horizontalCenter: parent.horizontalCenter

        // Title: Month and Year
        Text {
            text: Qt.locale().standaloneMonthName(month + 1) + " " + year
            font.bold: true
            font.pixelSize: theme ? theme.fontSize - 1 : 13
            color: theme ? theme.textContrast(theme.onHoverColor) : "#fff"
            horizontalAlignment: Text.AlignHCenter
            width: calendarGrid.implicitWidth
            height: calendarGrid.titleHeight
        }

        // Weekday headers
        Row {
            spacing: calendarGrid.spacing
            width: calendarGrid.implicitWidth
            height: calendarGrid.headerHeight
            Repeater {
                model: calendarGrid.weekDays
                Text {
                    text: modelData
                    font.bold: true
                    font.pixelSize: theme ? theme.fontSize - 2 : 12
                    color: theme ? theme.textContrast(theme.onHoverColor) : "#fff"
                    width: calendarGrid.cellWidth
                    height: calendarGrid.headerHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Calendar days
        Grid {
            columns: 7
            spacing: calendarGrid.spacing
            width: calendarGrid.implicitWidth
            height: calendarGrid.rowCount * calendarGrid.cellHeight + (calendarGrid.rowCount - 1) * calendarGrid.spacing

            Repeater {
                model: calendarGrid.firstDay + calendarGrid.daysInMonth
                delegate: Item {
                    width: calendarGrid.cellWidth
                    height: calendarGrid.cellHeight
                    Rectangle {
                        anchors.fill: parent
                        color: (index - calendarGrid.firstDay + 1) === calendarGrid.today.getDate()
                            ? (theme ? theme.inactiveColor : "#ffb347")
                            : "transparent"
                        radius: width / 2
                        visible: (index - calendarGrid.firstDay + 1) === calendarGrid.today.getDate()
                    }
                    Text {
                        anchors.centerIn: parent
                        text: index < calendarGrid.firstDay ? "" : (index - calendarGrid.firstDay + 1)
                        color: {
                            var d = index - calendarGrid.firstDay + 1
                            if (d === calendarGrid.today.getDate())
                                return theme ? theme.textContrast(theme.inactiveColor) : "#fff"
                            return theme ? theme.textContrast(theme.onHoverColor) : "#fff"
                        }
                        font.bold: (index - calendarGrid.firstDay + 1) === calendarGrid.today.getDate()
                        font.pixelSize: theme ? theme.fontSize - 3 : 11
                    }
                }
            }
        }
    }
}
