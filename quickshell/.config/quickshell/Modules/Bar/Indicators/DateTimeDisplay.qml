pragma ComponentBehavior: Bound

import QtQuick
import qs.Components
import qs.Config
import qs.Services.SystemInfo
import qs.Modules.Bar.Panels
import qs.Services.UI

Item {
  id: dateTimeDisplay

  readonly property color bgColor: mouseArea.containsMouse ? Theme.glassControlHoverColor : Theme.glassControlColor
  readonly property bool hasNotifications: notificationCount > 0
  readonly property int notificationCount: NotificationService.notifications.length
  required property string screenName

  height: Theme.itemHeight
  width: mainRow.width

  Rectangle {
    anchors.fill: parent
    border.color: mouseArea.containsMouse ? Theme.glassBorderHoverColor : Theme.glassBorderColor
    border.width: Theme.borderWidthThin
    color: dateTimeDisplay.bgColor
    radius: Theme.itemRadius

    Behavior on border.color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }
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
      color: !mouseArea.containsMouse && dateTimeDisplay.hasNotifications ? Theme.activeColor : Theme.textContrast(dateTimeDisplay.bgColor)
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      leftPadding: Theme.spacingSm
      text: NotificationService.doNotDisturb ? "󰂛 " : (dateTimeDisplay.hasNotifications ? "󱅫 " + dateTimeDisplay.notificationCount : " ")

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }
    }
    OText {
      anchors.verticalCenter: parent.verticalCenter
      bold: true
      color: Theme.textContrast(dateTimeDisplay.bgColor)
      rightPadding: Theme.spacingSm
      text: WeatherService.currentTemp + " " + TimeService.format("datetime")

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

    onClicked: ShellUiState.togglePanelForItem("notifications", dateTimeDisplay.screenName, dateTimeDisplay)
  }
  Loader {
    id: tooltipLoader

    readonly property bool requested: mouseArea.containsMouse && !ShellUiState.isPanelOpen("notifications", dateTimeDisplay.screenName)
    property bool retained: false

    active: requested || retained

    sourceComponent: Tooltip {
      id: tip

      isVisible: tooltipLoader.requested
      target: dateTimeDisplay

      onVisibleChanged: tooltipLoader.retained = visible

      Column {
        id: tooltipColumn

        readonly property color textColor: tip.fgColor

        spacing: Theme.spacingXs

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Theme.spacingSm

          OText {
            color: tooltipColumn.textColor
            text: WeatherService.weatherInfo()?.desc ?? ""
          }
          OText {
            color: tooltipColumn.textColor
            size: "sm"
            text: "in " + WeatherService.locationName
            visible: WeatherService.locationName.length > 0
          }
        }
        OText {
          anchors.horizontalCenter: parent.horizontalCenter
          color: tooltipColumn.textColor
          opacity: 0.7
          size: "sm"
          text: WeatherService.timeAgo ? "Last updated " + WeatherService.timeAgo : ""
          visible: WeatherService.timeAgo.length > 0
        }
        MinimalCalendar {
          today: TimeService.now
          weekStart: 6
        }
      }
    }
  }
}
