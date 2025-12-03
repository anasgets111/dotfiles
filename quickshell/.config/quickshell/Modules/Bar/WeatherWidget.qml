pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services.SystemInfo

Item {
  id: root

  property bool expanded: false
  readonly property var forecast: WeatherService.dailyForecast
  readonly property bool hasData: forecast && forecast.time && forecast.time.length > 0

  implicitHeight: mainCol.implicitHeight

  ColumnLayout {
    id: mainCol

    spacing: Theme.spacingSm

    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
    }

    // Header
    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingSm

      OButton {
        id: expandBtn

        Layout.fillWidth: true
        Layout.preferredHeight: Theme.itemHeight
        visible: root.hasData

        onClicked: root.expanded = !root.expanded

        RowLayout {
          anchors {
            left: parent.left
            margins: Theme.itemRadius
            right: parent.right
            verticalCenter: parent.verticalCenter
          }

          OText {
            Layout.alignment: Qt.AlignVCenter
            bold: true
            color: expandBtn.textColor
            text: root.expanded ? "Show Less" : "10 Day Forecast"
          }

          Item {
            Layout.fillWidth: true
          }

          OText {
            Layout.alignment: Qt.AlignVCenter
            color: Qt.alpha(expandBtn.textColor, 0.7)
            size: "xs"
            text: "updated " + WeatherService.timeAgo
          }
        }
      }

      Item {
        Layout.fillWidth: true
        visible: !root.hasData
      }

      IconButton {
        Layout.preferredHeight: Theme.itemHeight
        Layout.preferredWidth: Theme.itemHeight
        icon: ""
        tooltipText: "Refresh Weather"

        onClicked: WeatherService.refresh()
      }
    }

    // Content
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingSm

      // Summary Row
      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        visible: root.hasData

        WeatherDayCard {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          dayIndex: 0
          label: "Yesterday"
          opacity: 0.6
          showLabel: !root.expanded
        }

        WeatherDayCard {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          dayIndex: 1
          isToday: true
          label: "Today"
          showLabel: !root.expanded
        }

        WeatherDayCard {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          dayIndex: 2
          label: "Tomorrow"
          opacity: 0.8
          showLabel: !root.expanded
        }
      }

      // Expanded Grid
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.expanded ? gridLayout.implicitHeight : 0
        clip: true
        visible: root.hasData

        Behavior on Layout.preferredHeight {
          NumberAnimation {
            duration: 300
            easing.type: Easing.OutQuad
          }
        }

        GridLayout {
          id: gridLayout

          columnSpacing: Theme.spacingSm
          columns: 4
          rowSpacing: Theme.spacingSm

          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
          }

          Repeater {
            model: root.hasData ? Math.max(0, root.forecast.time.length - 3) : 0

            WeatherDayCard {
              required property int index

              Layout.fillWidth: true
              Layout.preferredHeight: Theme.itemHeight * 3
              dayIndex: index + 3
            }
          }
        }
      }

      // Loading / Error
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.itemHeight * 2
        visible: !root.hasData

        OText {
          anchors.centerIn: parent
          opacity: 0.7
          text: WeatherService.hasError ? "Weather Unavailable" : "Loading Forecast..."
        }

        OButton {
          text: "Retry"
          visible: WeatherService.hasError

          onClicked: WeatherService.refresh()

          anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
          }
        }
      }
    }
  }

  component WeatherDayCard: Rectangle {
    id: card

    readonly property string dateStr: hasData ? forecast.time[dayIndex] : ""
    required property int dayIndex
    readonly property var forecast: WeatherService.dailyForecast
    readonly property bool hasData: forecast && forecast.time && forecast.time.length > dayIndex
    property bool isToday: false
    property string label: ""
    readonly property real maxTemp: hasData ? forecast.temperature_2m_max[dayIndex] : 0
    readonly property real minTemp: hasData ? forecast.temperature_2m_min[dayIndex] : 0
    property bool showLabel: true
    readonly property int wCode: hasData ? forecast.weathercode[dayIndex] : -1
    readonly property var wInfo: WeatherService.weatherInfo(wCode)

    color: isToday ? Qt.alpha(Theme.activeColor, 0.2) : Qt.lighter(Theme.bgColor, 1.3)
    implicitHeight: col.implicitHeight + Theme.spacingLg
    radius: Theme.itemRadius

    ColumnLayout {
      id: col

      anchors.centerIn: parent
      spacing: Theme.spacingXs
      width: parent.width - Theme.spacingLg

      Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: Math.max(l1.implicitHeight, l2.implicitHeight)
        Layout.preferredWidth: Math.max(l1.implicitWidth, l2.implicitWidth)
        opacity: card.isToday ? 1.0 : 0.7

        OText {
          id: l1

          anchors.centerIn: parent
          bold: true
          opacity: visible ? 1 : 0
          size: "sm"
          text: card.label
          useActiveColor: card.isToday
          visible: card.showLabel && card.label !== ""

          Behavior on opacity {
            NumberAnimation {
              duration: 300
            }
          }
        }

        OText {
          id: l2

          anchors.centerIn: parent
          bold: true
          opacity: visible ? 1 : 0
          size: "sm"
          text: card.dateStr ? new Date(card.dateStr).toLocaleDateString(Qt.locale(), "ddd") : ""
          useActiveColor: card.isToday
          visible: !l1.visible

          Behavior on opacity {
            NumberAnimation {
              duration: 300
            }
          }
        }
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        color: Theme.textActiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize * 1.5
        text: card.wInfo.icon
      }

      OText {
        Layout.alignment: Qt.AlignHCenter
        bold: true
        size: "lg"
        text: Math.round(card.maxTemp) + "°"
      }

      OText {
        Layout.alignment: Qt.AlignHCenter
        opacity: 0.6
        size: "sm"
        text: Math.round(card.minTemp) + "°"
      }
    }
  }
}
