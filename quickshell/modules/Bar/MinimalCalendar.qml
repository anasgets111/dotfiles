pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: calendarGrid

    property int cellWidth: 32
    property int cellHeight: 22
    property int headerHeight: 22
    property int titleHeight: 22
    property int spacing: 8
    property var today: null
    property int month: (today ? today.getMonth() : (new Date()).getMonth())
    property int year: (today ? today.getFullYear() : (new Date()).getFullYear())
    property int daysInMonth: (new Date(year, month + 1, 0)).getDate()
    property int firstDay: (new Date(year, month, 1)).getDay()
    property var weekDays: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    property var displayedWeekDays: weekDays.slice(weekStart).concat(weekDays.slice(0, weekStart))
    property var theme: null
    property int rowCount: Math.ceil(((adjustedFirstDay) + daysInMonth) / 7)
    property int adjustedFirstDay: ((firstDay - weekStart + 7) % 7)
    property int weekStart: 0

    implicitWidth: (7 * cellWidth) + (6 * spacing)
    implicitHeight: titleHeight + headerHeight + (rowCount * cellHeight) + ((rowCount - 1) * spacing) + (2 * spacing)

    Column {
        spacing: calendarGrid.spacing
        anchors.horizontalCenter: parent.horizontalCenter

        Text {
            property string displayedTitle: Qt.formatDate(new Date(calendarGrid.year, calendarGrid.month), "MMMM yyyy")

            text: displayedTitle
            font.bold: true
            font.pixelSize: calendarGrid.theme ? calendarGrid.theme.fontSize - 1 : 13
            color: calendarGrid.theme ? calendarGrid.theme.textContrast(calendarGrid.theme.onHoverColor) : "#fff"
            horizontalAlignment: Text.AlignHCenter
            width: calendarGrid.implicitWidth
            height: calendarGrid.titleHeight
        }

        Row {
            spacing: calendarGrid.spacing
            width: calendarGrid.implicitWidth
            height: calendarGrid.headerHeight

            Repeater {
                model: calendarGrid.displayedWeekDays

                delegate: Text {
                    required property var modelData
                    required property int index
                    property int realWeekday: (index + calendarGrid.weekStart) % 7
                    text: modelData
                    font.bold: true
                    font.pixelSize: calendarGrid.theme ? calendarGrid.theme.fontSize - 2 : 12
                    color: realWeekday === 5 ? (calendarGrid.theme ? calendarGrid.theme.bgColor : "#11111b") : (calendarGrid.theme ? calendarGrid.theme.textContrast(calendarGrid.theme.onHoverColor) : "#fff")
                    width: calendarGrid.cellWidth
                    height: calendarGrid.headerHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Grid {
            columns: 7
            spacing: calendarGrid.spacing
            width: calendarGrid.implicitWidth
            height: calendarGrid.rowCount * calendarGrid.cellHeight + (calendarGrid.rowCount - 1) * calendarGrid.spacing

            Repeater {
                model: calendarGrid.adjustedFirstDay + calendarGrid.daysInMonth

                delegate: Item {
                    required property int index
                    property int displayedDay: index < calendarGrid.adjustedFirstDay ? 0 : (index - calendarGrid.adjustedFirstDay + 1)
                    property int col: index % 7

                    width: calendarGrid.cellWidth
                    height: calendarGrid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        color: parent.displayedDay > 0 && calendarGrid.today && calendarGrid.month === calendarGrid.today.getMonth() && calendarGrid.year === calendarGrid.today.getFullYear() && parent.displayedDay === calendarGrid.today.getDate() ? (calendarGrid.theme ? calendarGrid.theme.activeColor : "#CBA6F7") : (parent.col === ((5 + 7 - calendarGrid.weekStart) % 7) ? (calendarGrid.theme ? calendarGrid.theme.bgColor : "#11111b") : "transparent")
                        radius: width / 2
                        visible: parent.displayedDay > 0 && calendarGrid.today && calendarGrid.month === calendarGrid.today.getMonth() && calendarGrid.year === calendarGrid.today.getFullYear() && parent.displayedDay === calendarGrid.today.getDate()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: parent.index < calendarGrid.adjustedFirstDay ? "" : (parent.index - calendarGrid.adjustedFirstDay + 1)
                        color: {
                            var d = parent.index - calendarGrid.adjustedFirstDay + 1;
                            if (calendarGrid.today && d > 0 && calendarGrid.month === calendarGrid.today.getMonth() && calendarGrid.year === calendarGrid.today.getFullYear() && d === calendarGrid.today.getDate())
                                return calendarGrid.theme ? calendarGrid.theme.textContrast(calendarGrid.theme.activeColor) : "#fff";
                            if (parent.col === ((5 + 7 - calendarGrid.weekStart) % 7))
                                return calendarGrid.theme ? calendarGrid.theme.textContrast(calendarGrid.theme.bgColor) : "#fff";
                            return calendarGrid.theme ? calendarGrid.theme.textContrast(calendarGrid.theme.onHoverColor) : "#fff";
                        }
                        font.bold: calendarGrid.today && parent.displayedDay > 0 && calendarGrid.month === calendarGrid.today.getMonth() && calendarGrid.year === calendarGrid.today.getFullYear() && parent.displayedDay === calendarGrid.today.getDate()
                        font.pixelSize: calendarGrid.theme ? calendarGrid.theme.fontSize - 3 : 11
                    }
                }
            }
        }
    }
}
