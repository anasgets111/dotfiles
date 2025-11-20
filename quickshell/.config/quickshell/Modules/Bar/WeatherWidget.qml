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

  // width: parent.width // Removed to allow Layout.fillWidth to control size correctly respecting margins

  ColumnLayout {
    id: mainCol

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 8

    // Header Row (Expand/Collapse + Refresh)
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      OButton {
        id: expandBtn

        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.itemHeight * 1.3
        visible: root.hasData

        onClicked: root.expanded = !root.expanded

        ColumnLayout {
          anchors.left: parent.left
          anchors.leftMargin: Theme.itemRadius / 2
          anchors.right: parent.right
          anchors.rightMargin: Theme.itemRadius / 2
          anchors.verticalCenter: parent.verticalCenter
          spacing: -2

          OText {
            Layout.alignment: Qt.AlignHCenter
            color: expandBtn.textColor
            font.bold: true
            text: root.expanded ? "Show Less" : "10 Day Forecast"
          }

          Text {
            Layout.alignment: Qt.AlignRight
            color: Qt.alpha(expandBtn.textColor, 0.7)
            font.pixelSize: Theme.fontSize * 0.7
            text: "updated " + WeatherService.getTimeAgo()
          }
        }
      }

      // Spacer when button is hidden (loading/error state)
      Item {
        Layout.fillWidth: true
        visible: !root.hasData
      }

      IconButton {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredHeight: Theme.itemHeight
        Layout.preferredWidth: Theme.itemHeight
        icon: ""
        tooltipText: "Refresh Weather"

        onClicked: WeatherService.refresh()
      }
    }

    // Content Container
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 8

      // Top Row (Summary) - Always Visible
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
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

      // Expanded Grid (Remaining Days)
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

          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          columnSpacing: 8
          columns: 4
          rowSpacing: 8

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

      // Loading / No Data State
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
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Retry"
          visible: WeatherService.hasError

          onClicked: WeatherService.refresh()
        }
      }
    }
  }

  component WeatherDayCard: Rectangle {
    id: card

    readonly property string dateStr: root.hasData ? root.forecast.time[dayIndex] : ""
    property int dayIndex: 0
    property bool isToday: false
    property string label: ""
    readonly property real maxTemp: root.hasData ? root.forecast.temperature_2m_max[dayIndex] : 0
    readonly property real minTemp: root.hasData ? root.forecast.temperature_2m_min[dayIndex] : 0
    property bool showLabel: true
    readonly property int wCode: root.hasData ? root.forecast.weathercode[dayIndex] : -1
    readonly property var wInfo: WeatherService.weatherInfo(wCode)

    function getDayName(dateString) {
      if (!dateString)
        return "";
      const date = new Date(dateString);
      return date.toLocaleDateString(Qt.locale(), "ddd");
    }

    color: isToday ? Qt.alpha(Theme.activeColor, 0.2) : Qt.lighter(Theme.bgColor, 1.3)
    implicitHeight: col.implicitHeight + 16
    radius: Theme.itemRadius

    ColumnLayout {
      id: col

      anchors.centerIn: parent
      spacing: 2
      width: parent.width - 16

      Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: Math.max(l1.implicitHeight, l2.implicitHeight)
        Layout.preferredWidth: Math.max(l1.implicitWidth, l2.implicitWidth)
        opacity: card.isToday ? 1.0 : 0.7

        OText {
          id: l1

          anchors.centerIn: parent
          font.bold: true
          opacity: card.showLabel && card.label !== "" ? 1 : 0
          sizeMultiplier: 0.9
          text: card.label
          useActiveColor: card.isToday
          visible: opacity > 0

          Behavior on opacity {
            NumberAnimation {
              duration: 300
            }
          }
        }

        OText {
          id: l2

          anchors.centerIn: parent
          font.bold: true
          opacity: (card.showLabel && card.label !== "") ? 0 : 1
          sizeMultiplier: 0.9
          text: card.getDayName(card.dateStr)
          useActiveColor: card.isToday
          visible: opacity > 0

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
        font.bold: true
        sizeMultiplier: 1.1
        text: Math.round(card.maxTemp) + "°"
      }

      OText {
        Layout.alignment: Qt.AlignHCenter
        opacity: 0.6
        sizeMultiplier: 0.85
        text: Math.round(card.minTemp) + "°"
      }
    }
  }
}
