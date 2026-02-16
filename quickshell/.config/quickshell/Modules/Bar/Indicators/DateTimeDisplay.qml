import QtQuick
import qs.Components
import qs.Config
import qs.Services.SystemInfo
import qs.Modules.Bar.Panels
import qs.Services.UI

Item {
  id: dateTimeDisplay

  readonly property color bgColor: mouseArea.containsMouse ? Theme.onHoverColor : Theme.inactiveColor
  readonly property bool hasNotifications: notificationCount > 0
  readonly property int notificationCount: NotificationService.notifications?.length || 0
  readonly property bool panelOpen: ShellUiState.isPanelOpen("notifications", dateTimeDisplay.screenName)
  required property string screenName

  height: Theme.itemHeight
  width: mainRow.width

  Rectangle {
    anchors.fill: parent
    color: dateTimeDisplay.bgColor
    radius: Theme.itemRadius

    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }
  }

  Row {
    id: mainRow

    anchors.centerIn: parent
    height: parent.height
    spacing: Theme.spacingXs

    // Notification indicator
    Text {
      anchors.verticalCenter: parent.verticalCenter
      color: dateTimeDisplay.hasNotifications ? Theme.activeColor : Theme.textContrast(dateTimeDisplay.bgColor)
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      leftPadding: Theme.spacingSm
      text: NotificationService.doNotDisturb ? "󰂛 " : (dateTimeDisplay.hasNotifications ? "󱅫 " + dateTimeDisplay.notificationCount : " ")
      verticalAlignment: Text.AlignVCenter

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }
    }

    OText {
      id: textItem

      anchors.verticalCenter: parent.verticalCenter
      bold: true
      color: Theme.textContrast(dateTimeDisplay.bgColor)
      rightPadding: Theme.spacingSm
      text: WeatherService.currentTemp + " " + TimeService.format("datetime")
      verticalAlignment: Text.AlignVCenter

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }
    }
  }

  MouseArea {
    id: mouseArea

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: function (mouse) {
      ShellUiState.togglePanelForItem("notifications", dateTimeDisplay.screenName, dateTimeDisplay);
    }
  }

  // Tooltip with weather info and calendar
  Tooltip {
    id: tooltip

    isVisible: mouseArea.containsMouse && !dateTimeDisplay.panelOpen
    target: dateTimeDisplay

    Column {
      id: tooltipColumn

      readonly property color textColor: Theme.textContrast(Theme.onHoverColor)

      spacing: Theme.spacingXs

      // First row: description and place
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingSm

        OText {
          color: tooltipColumn.textColor
          text: (WeatherService.weatherInfo() || {}).desc || ""
        }

        OText {
          color: tooltipColumn.textColor
          size: "sm"
          text: "in " + WeatherService.locationName
          visible: WeatherService.locationName.length > 0
        }
      }

      // Last updated row
      OText {
        anchors.horizontalCenter: parent.horizontalCenter
        color: tooltipColumn.textColor
        opacity: 0.7
        size: "sm"
        text: WeatherService.timeAgo ? "Last updated " + WeatherService.timeAgo : ""
        visible: WeatherService.timeAgo.length > 0
      }

      // Load the calendar
      Loader {
        active: mouseArea.containsMouse
        asynchronous: true

        sourceComponent: MinimalCalendar {
          today: TimeService.now
          weekStart: 6
        }
      }
    }
  }
}
