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
    property var today: null
    property int month: (today ? today.getMonth() : (new Date()).getMonth())
    property int year: (today ? today.getFullYear() : (new Date()).getFullYear())
    property int daysInMonth: (new Date(year, month + 1, 0)).getDate()
    property int firstDay: (new Date(year, month, 1)).getDay()
    property var weekDays: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    // Rotated week days based on weekStart
    property var displayedWeekDays: weekDays.slice(weekStart).concat(weekDays.slice(0, weekStart))

    // Expose theme properties for parent to set if needed
    property var theme: null

    // Calculate number of rows needed for the month grid
    property int rowCount: Math.ceil(((adjustedFirstDay) + daysInMonth) / 7)

    // Adjust firstDay to respect weekStart
    property int adjustedFirstDay: ((firstDay - weekStart + 7) % 7)

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
            property string displayedTitle: Qt.formatDate(new Date(calendarGrid.year, calendarGrid.month), "MMMM yyyy")
            text: displayedTitle
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
                model: calendarGrid.displayedWeekDays
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
                model: calendarGrid.adjustedFirstDay + calendarGrid.daysInMonth
                delegate: Item {
                    width: calendarGrid.cellWidth
                    height: calendarGrid.cellHeight
                    property int displayedDay: index < calendarGrid.adjustedFirstDay ? 0 : (index - calendarGrid.adjustedFirstDay + 1)
                    Rectangle {
                        anchors.fill: parent
                        color: (index - calendarGrid.adjustedFirstDay + 1) === calendarGrid.today.getDate()
                            ? (theme ? theme.inactiveColor : "#ffb347")
                            : "transparent"
                        radius: width / 2
                        visible: (index - calendarGrid.adjustedFirstDay + 1) === calendarGrid.today.getDate()
                    }
                    Text {
                        anchors.centerIn: parent
                        text: index < calendarGrid.adjustedFirstDay ? "" : (index - calendarGrid.adjustedFirstDay + 1)
                        color: {
                            var d = index - calendarGrid.adjustedFirstDay + 1
                            if (d === calendarGrid.today.getDate())
                                return theme ? theme.textContrast(theme.inactiveColor) : "#fff"
                            return theme ? theme.textContrast(theme.onHoverColor) : "#fff"
                        }
                        font.bold: (index - calendarGrid.adjustedFirstDay + 1) === calendarGrid.today.getDate()
                        font.pixelSize: theme ? theme.fontSize - 3 : 11
                    }
                    Component.onCompleted: {
                        if (displayedDay > 0)
                            console.log("MinimalCalendar Debug - Displayed Day Cell:", displayedDay)
                    }
                }
            }
        }
    }
}
