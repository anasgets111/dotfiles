import QtQuick
import qs.Config
import qs.Services.SystemInfo

Item {
  id: dateTimeDisplay

  property string formattedDateTime: TimeService.format("datetime")
  property string weatherText: WeatherService.currentTemp

  height: Theme.itemHeight
  width: textItem.width

  Rectangle {
    anchors.fill: parent
    color: Theme.inactiveColor
    radius: Theme.itemRadius
  }
  Text {
    id: textItem

    anchors.centerIn: parent
    color: Theme.textContrast(Theme.inactiveColor)
    font.bold: true
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    padding: 8
    text: WeatherService.currentTemp + " " + dateTimeDisplay.formattedDateTime
  }
  MouseArea {
    id: dateTimeMouseArea

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: {
      // Refresh weather using existing coordinates only (skip IP geolocation)
      if (!isNaN(WeatherService.latitude) && !isNaN(WeatherService.longitude))
        WeatherService.fetchCurrentTemp(WeatherService.latitude, WeatherService.longitude);
    }
  }

  // Tooltip background and content: Rectangle is now parent of Column
  Item {
    id: tooltip

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.bottom
    anchors.topMargin: 8
    height: tooltipColumn.implicitHeight + 8
    opacity: dateTimeMouseArea.containsMouse ? 1 : 0
    visible: dateTimeMouseArea.containsMouse
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
      z: -1
    }
    Column {
      id: tooltipColumn

      property real widest: Math.max(firstRow.width, calendar.width)

      anchors.centerIn: parent
      spacing: 6
      width: widest

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
          text: WeatherService.getWeatherDescriptionFromCode()
        }
        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize - 2
          text: "in " + WeatherService.locationName
          visible: WeatherService.locationName.length > 0
        }
      }

      // Second row: extracted MinimalCalendar component
      MinimalCalendar {
        id: calendar

        theme: Theme
        today: TimeService.now
        weekStart: 6
      }
    }
  }
}
