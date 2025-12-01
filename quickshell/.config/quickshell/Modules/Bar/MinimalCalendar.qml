pragma ComponentBehavior: Bound

import QtQuick

Item {
  id: root

  property int cellHeight: 22
  property int cellWidth: 32
  readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
  readonly property int firstDayOffset: ((new Date(year, month, 1).getDay() - weekStart + 7) % 7)
  property int headerHeight: 22
  readonly property int month: (today ?? new Date()).getMonth()
  readonly property int rowCount: Math.ceil((firstDayOffset + daysInMonth) / 7)
  readonly property int saturdayCol: (6 - weekStart + 7) % 7
  property int spacing: 8
  property var theme: null
  property int titleHeight: 22
  property var today: null
  readonly property int todayDate: today?.getDate() ?? 0
  readonly property var weekDays: {
    const days = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
    return days.slice(weekStart).concat(days.slice(0, weekStart));
  }
  property int weekStart: 0

  // Computed from today or current date
  readonly property int year: (today ?? new Date()).getFullYear()

  function isCurrentMonth(): bool {
    return today && month === today.getMonth() && year === today.getFullYear();
  }

  implicitHeight: titleHeight + headerHeight + (rowCount * cellHeight) + ((rowCount + 1) * spacing)
  implicitWidth: (7 * cellWidth) + (6 * spacing)

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: root.spacing

    Text {
      color: root.theme?.textContrast(root.theme.onHoverColor) ?? "#fff"
      font.bold: true
      font.pixelSize: root.theme?.fontSize - 1 ?? 13
      height: root.titleHeight
      horizontalAlignment: Text.AlignHCenter
      text: Qt.formatDate(new Date(root.year, root.month), "MMMM yyyy")
      width: root.implicitWidth
    }

    Row {
      spacing: root.spacing

      Repeater {
        model: root.weekDays

        Text {
          required property int index
          required property string modelData

          color: index === root.saturdayCol ? (root.theme?.bgColor ?? "#11111b") : (root.theme?.textContrast(root.theme.onHoverColor) ?? "#fff")
          font.bold: true
          font.pixelSize: root.theme?.fontSize - 2 ?? 12
          height: root.headerHeight
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          verticalAlignment: Text.AlignVCenter
          width: root.cellWidth
        }
      }
    }

    Grid {
      columns: 7
      spacing: root.spacing

      Repeater {
        model: root.firstDayOffset + root.daysInMonth

        Item {
          id: cell

          readonly property int col: index % 7
          readonly property int day: index >= root.firstDayOffset ? index - root.firstDayOffset + 1 : 0
          required property int index
          readonly property bool isSaturday: col === root.saturdayCol
          readonly property bool isToday: day > 0 && root.isCurrentMonth() && day === root.todayDate

          height: root.cellHeight
          width: root.cellWidth

          Rectangle {
            anchors.fill: parent
            color: root.theme?.activeColor ?? "#CBA6F7"
            radius: width / 2
            visible: cell.isToday
          }

          Text {
            anchors.centerIn: parent
            color: cell.isToday ? (root.theme?.textContrast(root.theme.activeColor) ?? "#fff") : cell.isSaturday ? (root.theme?.textContrast(root.theme.bgColor) ?? "#fff") : (root.theme?.textContrast(root.theme.onHoverColor) ?? "#fff")
            font.bold: cell.isToday
            font.pixelSize: root.theme?.fontSize - 3 ?? 11
            text: cell.day > 0 ? cell.day : ""
          }
        }
      }
    }
  }
}
