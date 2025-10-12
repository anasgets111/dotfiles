pragma ComponentBehavior: Bound

import QtQuick

Item {
  id: calendarGrid

  property int adjustedFirstDay: ((firstDay - weekStart + 7) % 7)
  property int cellHeight: 22
  property int cellWidth: 32
  property int daysInMonth: (new Date(year, month + 1, 0)).getDate()
  property var displayedWeekDays: weekDays.slice(weekStart).concat(weekDays.slice(0, weekStart))
  property int firstDay: (new Date(year, month, 1)).getDay()
  property int headerHeight: 22
  property int month: (today ? today.getMonth() : (new Date()).getMonth())
  property int rowCount: Math.ceil(((adjustedFirstDay) + daysInMonth) / 7)
  property int spacing: 8
  property var theme: null
  property int titleHeight: 22
  property var today: null
  property var weekDays: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
  property int weekStart: 0
  property int year: (today ? today.getFullYear() : (new Date()).getFullYear())

  implicitHeight: titleHeight + headerHeight + (rowCount * cellHeight) + ((rowCount - 1) * spacing) + (2 * spacing)
  implicitWidth: (7 * cellWidth) + (6 * spacing)

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: calendarGrid.spacing

    Text {
      property string displayedTitle: Qt.formatDate(new Date(calendarGrid.year, calendarGrid.month), "MMMM yyyy")

      color: calendarGrid.theme ? calendarGrid.theme.textContrast(calendarGrid.theme.onHoverColor) : "#fff"
      font.bold: true
      font.pixelSize: calendarGrid.theme ? calendarGrid.theme.fontSize - 1 : 13
      height: calendarGrid.titleHeight
      horizontalAlignment: Text.AlignHCenter
      text: displayedTitle
      width: calendarGrid.implicitWidth
    }

    Row {
      height: calendarGrid.headerHeight
      spacing: calendarGrid.spacing
      width: calendarGrid.implicitWidth

      Repeater {
        model: calendarGrid.displayedWeekDays

        delegate: Text {
          required property int index
          required property var modelData
          property int realWeekday: (index + calendarGrid.weekStart) % 7

          color: realWeekday === 5 ? (calendarGrid.theme ? calendarGrid.theme.bgColor : "#11111b") : (calendarGrid.theme ? calendarGrid.theme.textContrast(calendarGrid.theme.onHoverColor) : "#fff")
          font.bold: true
          font.pixelSize: calendarGrid.theme ? calendarGrid.theme.fontSize - 2 : 12
          height: calendarGrid.headerHeight
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          verticalAlignment: Text.AlignVCenter
          width: calendarGrid.cellWidth
        }
      }
    }

    Grid {
      columns: 7
      height: calendarGrid.rowCount * calendarGrid.cellHeight + (calendarGrid.rowCount - 1) * calendarGrid.spacing
      spacing: calendarGrid.spacing
      width: calendarGrid.implicitWidth

      Repeater {
        model: calendarGrid.adjustedFirstDay + calendarGrid.daysInMonth

        delegate: Item {
          property int col: index % 7
          property int displayedDay: index < calendarGrid.adjustedFirstDay ? 0 : (index - calendarGrid.adjustedFirstDay + 1)
          required property int index

          height: calendarGrid.cellHeight
          width: calendarGrid.cellWidth

          Rectangle {
            anchors.fill: parent
            color: parent.displayedDay > 0 && calendarGrid.today && calendarGrid.month === calendarGrid.today.getMonth() && calendarGrid.year === calendarGrid.today.getFullYear() && parent.displayedDay === calendarGrid.today.getDate() ? (calendarGrid.theme ? calendarGrid.theme.activeColor : "#CBA6F7") : (parent.col === ((5 + 7 - calendarGrid.weekStart) % 7) ? (calendarGrid.theme ? calendarGrid.theme.bgColor : "#11111b") : "transparent")
            radius: width / 2
            visible: parent.displayedDay > 0 && calendarGrid.today && calendarGrid.month === calendarGrid.today.getMonth() && calendarGrid.year === calendarGrid.today.getFullYear() && parent.displayedDay === calendarGrid.today.getDate()
          }

          Text {
            anchors.centerIn: parent
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
            text: parent.index < calendarGrid.adjustedFirstDay ? "" : (parent.index - calendarGrid.adjustedFirstDay + 1)
          }
        }
      }
    }
  }
}
