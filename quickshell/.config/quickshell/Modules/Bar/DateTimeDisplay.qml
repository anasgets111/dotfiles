import QtQuick
import qs.Config
import qs.Services.SystemInfo

Item {
  id: dateTimeDisplay

  property string formattedDateTime: TimeService.format("datetime")
  readonly property bool hasNotifications: notificationCount > 0
  readonly property int notificationCount: NotificationService.notifications?.length || 0
  property string weatherIcon: (WeatherService.weatherInfo() || {}).icon || ""
  property string weatherText: WeatherService.currentTemp || ""

  height: Theme.itemHeight
  width: mainRow.width

  Rectangle {
    anchors.fill: parent
    color: mouseArea.containsMouse ? Theme.onHoverColor : Theme.inactiveColor
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
    anchors.verticalCenterOffset: 0
    height: parent.height
    spacing: 6

    // Notification indicator
    Text {
      id: notifIndicator

      anchors.verticalCenter: parent.verticalCenter
      color: dateTimeDisplay.hasNotifications ? Theme.activeColor : Theme.textContrast(mouseArea.containsMouse ? Theme.onHoverColor : Theme.inactiveColor)
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      leftPadding: 8
      text: NotificationService.doNotDisturb ? "󰂛 " : (dateTimeDisplay.hasNotifications ? "󱅫 " + dateTimeDisplay.notificationCount : " ")
      verticalAlignment: Text.AlignVCenter

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }
    }

    Text {
      id: textItem

      anchors.verticalCenter: parent.verticalCenter
      color: Theme.textContrast(mouseArea.containsMouse ? Theme.onHoverColor : Theme.inactiveColor)
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      leftPadding: 0
      rightPadding: 8
      text: WeatherService.currentTemp + " " + dateTimeDisplay.formattedDateTime
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
      if (notificationPanelLoader.active) {
        notificationPanelLoader.active = false;
      } else {
        notificationPanelLoader.active = true;
      }
    }
  }

  // Tooltip background and content: Rectangle is now parent of Column
  Item {
    id: tooltip

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.bottom
    anchors.topMargin: 8
    height: tooltipColumn.implicitHeight + 8
    opacity: mouseArea.containsMouse && !notificationPanelLoader.active ? 1 : 0
    visible: mouseArea.containsMouse && !notificationPanelLoader.active
    width: tooltipColumn.width + 16

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.OutCubic
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.onHoverColor
      radius: Theme.itemRadius
    }

    Column {
      id: tooltipColumn

      anchors.centerIn: parent
      spacing: 6
      width: implicitWidth

      // First row: description and place
      Row {
        id: firstRow

        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        width: implicitWidth

        Text {
          id: tooltipText

          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          text: (WeatherService.weatherInfo() || {}).desc || ""
        }

        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize - 2
          text: "in " + WeatherService.locationName
          visible: WeatherService.locationName.length > 0
        }
      }

      // Last updated row
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.textContrast(Theme.onHoverColor)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        opacity: 0.7
        text: WeatherService.timeAgo ? "Last updated " + WeatherService.timeAgo : ""
        visible: WeatherService.timeAgo.length > 0
      }

      // Load the calendar immediately (simple Loader vs LazyLoader to avoid hover teardown issues)
      Loader {
        id: calendarLoader

        active: mouseArea.containsMouse
        // Always load the calendar so it is ready instantly when tooltip appears
        asynchronous: true
        visible: mouseArea.containsMouse

        sourceComponent: MinimalCalendar {
          id: calendar

          theme: Theme
          // Ensure 'today' is a Date object for MinimalCalendar
          today: TimeService.now
          weekStart: 6
        }
      }
    }
  }

  // Component definition for NotificationHistoryPanel (better isolation)
  Component {
    id: notificationPanelComponent

    NotificationHistoryPanel {
      property var loaderRef

      onPanelClosed: loaderRef.active = false
    }
  }

  // Loader for lazy-loading the panel
  Loader {
    id: notificationPanelLoader

    active: false
    sourceComponent: notificationPanelComponent

    onLoaded: {
      const panel = item as NotificationHistoryPanel;
      panel.loaderRef = notificationPanelLoader;
      panel.openAtItem(dateTimeDisplay, 0, 0);
    }
  }
}
