import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Io

Item {
  id: root
  implicitHeight: Theme.itemHeight
  implicitWidth: icon.implicitWidth + percentText.implicitWidth + row.spacing + 12

  property int flashPhase: 0

  Timer {
    id: flashTimer
    interval: 200 // ms per phase, adjust for speed
    repeat: true
    onTriggered: {
      if (root.flashPhase < 4) {
        root.flashPhase += 1
      } else {
        root.flashPhase = 0
        flashTimer.stop()
      }
    }
  }

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
    color: batteryMouseArea.powerProfile === "power-saver"
        ? Theme.powerSaveColor
        : percentage <= 0.10 ? "#f38ba8"
        : percentage <= 0.20 ? "#fab387"
        : Theme.activeColor
    radius: height / 2
    Behavior on color {
        ColorAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutCubic
        }
    }
  }

  MouseArea {
    id: batteryMouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    // Tooltip logic
    property string remainingTimeText: {
        function formatDuration(seconds) {
            if (seconds <= 0)
                return "Calculating…";
            var hours = Math.floor(seconds / 3600);
            var minutes = Math.round((seconds % 3600) / 60);
            if (hours > 0)
                return hours + "h " + minutes + "m";
            else
                return minutes + "m";
        }
        if (isCharging && device.timeToFull > 0)
            return "Time to full: " + formatDuration(device.timeToFull);
        else if (!isCharging && device.timeToEmpty > 0)
            return "Time remaining: " + formatDuration(device.timeToEmpty);
        else
            return "Calculating…";
    }

    // Power profile logic
    property string powerProfile: ""
    Process {
        id: powerProfileProc
        command: ["powerprofilesctl", "get"]
        running: batteryMouseArea.containsMouse
        stdout: StdioCollector {
            onStreamFinished: {
                batteryMouseArea.powerProfile = text.trim()
            }
        }
    }

    // Process to set profile
    Process {
        id: setProfileProc
        stdout: StdioCollector { }
        onExited: {
            powerProfileProc.running = true
        }
    }

    onClicked: {
        var nextProfile = (powerProfile === "performance") ? "power-saver" : "performance";
        setProfileProc.command = ["powerprofilesctl", "set", nextProfile];
        setProfileProc.running = true;
        root.flashPhase = 1
        flashTimer.start();
    }

    // Hover background
    Rectangle {
        anchors.fill: parent
        color: (root.flashPhase === 1 || root.flashPhase === 3)
            ? "#ffe066"
            : batteryMouseArea.containsMouse ? Theme.onHoverColor : "transparent"
        radius: height / 2
        z: -1
        Behavior on color {
            ColorAnimation {
                duration: 100
                easing.type: Easing.OutCubic
            }
        }
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

    Rectangle {
        id: tooltip
        visible: batteryMouseArea.containsMouse
                 && (device.timeToFull > 0 || device.timeToEmpty > 0)
        color: Theme.onHoverColor
        radius: Theme.itemRadius
        width: tooltipColumn.width + 16
        height: tooltipColumn.height + 8
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

        Column {
            id: tooltipColumn
            anchors.centerIn: parent
            spacing: 2

            Text {
                id: tooltipText
                text: batteryMouseArea.remainingTimeText
                color: Theme.textContrast(
                    batteryMouseArea.containsMouse ? Theme.onHoverColor : Theme.inactiveColor
                )
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
            }

            // Show power profile if available
            Text {
                id: profileText
                visible: batteryMouseArea.powerProfile.length > 0
                text: "Profile: " + batteryMouseArea.powerProfile
                color: Theme.textContrast(
                    batteryMouseArea.containsMouse ? Theme.onHoverColor : Theme.inactiveColor
                )
                font.pixelSize: Theme.fontSize - 2
                font.family: Theme.fontFamily
            }
        }
    }
  }


}
