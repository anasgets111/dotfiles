pragma ComponentBehavior: Bound

import QtQuick
import qs.Components
import qs.Config

Item {
  id: root

  readonly property int cellHeight: Theme.fontXl
  readonly property int cellWidth: Theme.controlWidthSm
  readonly property color contrastColor: Theme.textContrast(Theme.onHoverColor)
  readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
  readonly property int firstDayOffset: ((new Date(year, month, 1).getDay() - weekStart + 7) % 7)
  readonly property int month: (today ?? new Date()).getMonth()
  readonly property int rowCount: Math.ceil((firstDayOffset + daysInMonth) / 7)
  readonly property int saturdayCol: (6 - weekStart + 7) % 7
  property var today: null
  readonly property int todayDate: today?.getDate() ?? 0
  readonly property var weekDays: {
    const days = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
    return days.slice(weekStart).concat(days.slice(0, weekStart));
  }
  property int weekStart: 0
  readonly property int year: (today ?? new Date()).getFullYear()

  function isCurrentMonth(): bool {
    return today && month === today.getMonth() && year === today.getFullYear();
  }

  implicitHeight: (3 + rowCount) * cellHeight + (rowCount + 1) * Theme.spacingXs
  implicitWidth: 7 * cellWidth + 6 * Theme.spacingXs

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Theme.spacingXs

    OText {
      bold: true
      color: root.contrastColor
      height: root.cellHeight
      horizontalAlignment: Text.AlignHCenter
      text: Qt.formatDate(new Date(root.year, root.month), "MMMM yyyy")
      width: root.implicitWidth
    }

    Row {
      spacing: Theme.spacingXs

      Repeater {
        model: root.weekDays

        OText {
          required property int index
          required property string modelData

          bold: true
          color: index === root.saturdayCol ? Theme.textContrast(Theme.bgColor) : root.contrastColor
          height: root.cellHeight
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          verticalAlignment: Text.AlignVCenter
          width: root.cellWidth
        }
      }
    }

    Grid {
      columns: 7
      spacing: Theme.spacingXs

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
            color: Theme.activeColor
            radius: width / 2
            visible: cell.isToday
          }

          OText {
            anchors.centerIn: parent
            bold: cell.isToday
            color: cell.isToday ? Theme.textContrast(Theme.activeColor) : cell.isSaturday ? Theme.textContrast(Theme.bgColor) : root.contrastColor
            size: "sm"
            text: cell.day > 0 ? cell.day : ""
          }
        }
      }
    }
  }
}
