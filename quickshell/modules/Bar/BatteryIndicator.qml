import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

Item {
  id: root
  implicitHeight: Theme.itemHeight
  implicitWidth: icon.implicitWidth + percentText.implicitWidth + row.spacing + 12

  // Battery device and state
  property var   device: UPower.displayDevice
  property real  percentage: device.percentage
  property int   state:      device.state
  property bool  isCharging: state === UPowerDeviceState.Charging
  property bool  isLowAndNotCharging:
    device.isLaptopBattery && percentage <= 0.20 && !isCharging
  property bool  isCriticalAndNotCharging:
    device.isLaptopBattery && percentage <= 0.10 && !isCharging
  property bool  isSuspendingAndNotCharging:
    device.isLaptopBattery && percentage <= 0.05 && !isCharging

  // Alerts & suspend
  onIsLowAndNotChargingChanged:
    if (isLowAndNotCharging)
      Quickshell.execDetached(["notify-send", "Low Battery", "Plug in soon!"])
  onIsCriticalAndNotChargingChanged:
    if (isCriticalAndNotCharging)
      Quickshell.execDetached([
        "notify-send", "-u", "critical",
        "Critical Battery", "Automatic suspend at 5%!"
      ])
  onIsSuspendingAndNotChargingChanged:
    if (isSuspendingAndNotCharging)
      Quickshell.execDetached(["systemctl", "suspend"])

  // Background bar (inactive color)
  Rectangle {
    anchors.fill: parent
    color: Theme.inactiveColor
    radius: height / 2
  }

  // Fill bar
  Rectangle {
    id: fill
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: parent.width * percentage
    color: percentage <= 0.10 ? "#f38ba8" :
           percentage <= 0.20 ? "#fab387" :
           Theme.activeColor
    radius: height / 2
  }

  // Icon and percentage row
  Row {
    id: row
    anchors.centerIn: parent
    spacing: 4

    // Conditional icon: Nerd Font plug if charging, battery level otherwise
    Text {
      id: icon
      anchors.verticalCenter: parent.verticalCenter
      text: isCharging ? "" : // nf-fa-plug
            percentage > 0.8 ? "" : // battery full
            percentage > 0.6 ? "" : // battery three quarters
            percentage > 0.4 ? "" : // battery half
            percentage > 0.2 ? "" : // battery quarter
                               ""   // battery empty
      font.pixelSize: Theme.fontSize
      font.family: Theme.fontFamily
      font.bold: true
      color: Theme.textContrast(
          percentage > 0.5
              ? (percentage <= 0.10 ? "#f38ba8"
                  : percentage <= 0.20 ? "#fab387"
                  : Theme.activeColor)
              : Theme.inactiveColor
      )
      z: 1
    }

    // Percentage text
    Text {
      id: percentText
      text: Math.round(percentage * 100) + "%"
      font.pixelSize: Theme.fontSize
      font.family: Theme.fontFamily
      font.bold: true
      color: Theme.textContrast(
          percentage > 0.5
              ? (percentage <= 0.10 ? "#f38ba8"
                  : percentage <= 0.20 ? "#fab387"
                  : Theme.activeColor)
              : Theme.inactiveColor
      )
      z: 1
      padding: 4
    }
  }

  MouseArea {
      id: batteryMouseArea
      anchors.fill: parent
      hoverEnabled: true

      // Tooltip logic
      property string remainingTimeText: {
          if (isCharging && device.timeToFull > 0)
              return "Time to full: " + Qt.formatTime(new Date(device.timeToFull * 1000), "hh:mm");
          else if (!isCharging && device.timeToEmpty > 0)
              return "Time remaining: " + Qt.formatTime(new Date(device.timeToEmpty * 1000), "hh:mm");
          else
              return "Calculating…";
      }

      Rectangle {
          id: tooltip
          visible: batteryMouseArea.containsMouse
                   && (device.timeToFull > 0 || device.timeToEmpty > 0)
          color: Theme.onHoverColor
          radius: Theme.itemRadius
          width: tooltipText.width + 16
          height: tooltipText.height + 8
          anchors.top: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.topMargin: 8
          opacity: batteryMouseArea.containsMouse ? 1 : 0
          Behavior on opacity {
              NumberAnimation {
                  duration: Theme.animationDuration
                  easing.type: Easing.OutCubic
              }
          }

          Text {
              id: tooltipText
              anchors.centerIn: parent
              text: batteryMouseArea.remainingTimeText
              color: Theme.textContrast(
                  batteryMouseArea.containsMouse ? Theme.onHoverColor : Theme.inactiveColor
              )
              font.pixelSize: Theme.fontSize
              font.family: Theme.fontFamily
          }
      }
  }


}
