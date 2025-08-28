pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Widgets

Item {
  id: root

  readonly property color batteryColor: percentage <= 0.1 ? "#f38ba8" : percentage <= 0.2 ? "#fab387" : Theme.activeColor
  readonly property string batteryIcon: {
    if (isCharging)
      return "";
    if (device.state === UPowerDeviceState.PendingCharge)
      return "󰂄";
    const icons = ["", "", "", "", ""];
    return icons[Math.min(Math.floor(percentage * 5), 4)];
  }
  readonly property color bgColor: Theme.inactiveColor
  property var device: UPower.displayDevice
  readonly property bool isCharging: device.state === UPowerDeviceState.Charging
  readonly property bool isCriticalAndNotCharging: DetectEnv.isLaptopBattery && percentage <= 0.1 && !isCharging
  readonly property bool isLowAndNotCharging: DetectEnv.isLaptopBattery && percentage <= 0.2 && !isCharging
  readonly property bool isPluggedIn: isCharging || device.state === UPowerDeviceState.PendingCharge
  readonly property bool isSuspendingAndNotCharging: DetectEnv.isLaptopBattery && percentage <= 0.05 && !isCharging

  // flash animation state
  property real overlayFlashWidth: 2
  property real overlayFlashX: implicitWidth / 2 - overlayFlashWidth / 2
  property real percentage: Math.max(0, Math.min(device.percentage, 1))
  readonly property color textColor: Theme.textContrast(percentage > 0.6 ? batteryColor : bgColor)
  property int widthPhase: 0

  function sendNotification(summary, body, critical) {
    const s = (summary ?? "").replace(/"/g, '\\"');
    const b = (body ?? "").replace(/"/g, '\\"');
    const qml = 'import Quickshell.Services.Notifications\n' + 'Notification { summary: "' + s + '"; body: "' + b + '"; expireTimeout: 5000; urgency: ' + (critical ? 'NotificationUrgency.Critical' : 'NotificationUrgency.Normal') + '; transient: true }';
    Qt.createQmlObject(qml, root, "BatteryNotification");
  }

  implicitHeight: Theme.itemHeight
  implicitWidth: 80
  visible: DetectEnv.isLaptopBattery

  onIsCriticalAndNotChargingChanged: if (isCriticalAndNotCharging)
    sendNotification("Critical Battery", "Automatic suspend at 5%!", true)
  onIsLowAndNotChargingChanged: if (isLowAndNotCharging)
    sendNotification("Low Battery", "Plug in soon!", false)
  onIsPluggedInChanged: if (isPluggedIn) {
    if (widthTimer.running)
      widthTimer.stop();
    widthPhase = 1;
    widthTimer.start();
  }
  onIsSuspendingAndNotChargingChanged: if (isSuspendingAndNotCharging)
    Quickshell.execDetached(["systemctl", "suspend"])

  Timer {
    id: widthTimer

    interval: 200
    repeat: true

    onTriggered: {
      root.widthPhase = root.widthPhase < 4 ? root.widthPhase + 1 : 0;
      if (root.widthPhase === 0)
        stop();
    }
  }

  Rectangle {
    anchors.fill: parent
    color: root.bgColor
    radius: height / 2
  }

  // fill clip
  ClippingRectangle {
    id: waterClip

    readonly property real drawWidth: phase > 0 ? ((phase % 2 === 1) ? 0 : fullWidth) : fullWidth
    readonly property real fullWidth: width * root.percentage
    readonly property int phase: root.widthPhase

    anchors.fill: parent
    color: "transparent"
    radius: height / 2

    Rectangle {
      color: root.batteryColor
      width: waterClip.drawWidth

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.OutCubic
        }
      }
      Behavior on width {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.OutCubic
        }
      }

      anchors {
        bottom: parent.bottom
        left: parent.left
        top: parent.top
      }
    }
  }

  MouseArea {
    id: batteryArea

    readonly property string remainingTimeText: {
      if (root.device.state === UPowerDeviceState.FullyCharged)
        return "Fully Charged";
      if (root.isCharging && root.device.timeToFull > 0)
        return "Time to full: " + fmt(root.device.timeToFull);
      if (root.device.state === UPowerDeviceState.PendingCharge)
        return "Charge Limit Reached";
      if (!root.isCharging && root.device.isOnline && Math.round(root.percentage * 100) === 100)
        return "Connected";
      if (!root.isCharging && root.device.timeToEmpty > 0)
        return "Time remaining: " + fmt(root.device.timeToEmpty);
      return "Calculating…";
    }

    function fmt(s) {
      if (s <= 0)
        return "Calculating…";
      const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
      return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: {
      if (DetectEnv.batteryManager === "ppd") {
        const canPerf = PowerProfiles.hasPerformanceProfile;
        PowerProfiles.profile = PowerProfiles.profile === PowerProfile.Performance ? PowerProfile.PowerSaver : (canPerf ? PowerProfile.Performance : PowerProfile.PowerSaver);
        PowerMgmt.refreshPowerInfo();
      }

      if (overlayFadeTimer.running)
        overlayFadeTimer.stop();
      if (overlayFlashStartTimer.running)
        overlayFlashStartTimer.stop();

      overlayFlash.opacity = 0;
      root.overlayFlashWidth = 2;
      root.overlayFlashX = implicitWidth / 2 - root.overlayFlashWidth / 2;
      overlayFlashStartTimer.start();
    }

    Rectangle {
      anchors.fill: parent
      color: batteryArea.containsMouse ? Theme.onHoverColor : "transparent"
      radius: height / 2

      Behavior on color {
        ColorAnimation {
          duration: 100
          easing.type: Easing.OutCubic
        }
      }
    }

    Rectangle {
      id: overlayFlash

      color: "#ffe066"
      height: parent.height
      opacity: root.overlayFlashWidth > 2 ? 1 : 0
      radius: height / 2
      width: root.overlayFlashWidth
      x: root.overlayFlashX
      y: 0

      Behavior on opacity {
        NumberAnimation {
          duration: 200
          easing.type: Easing.OutCubic
        }
      }
      Behavior on width {
        NumberAnimation {
          duration: 600
          easing.type: Easing.OutCubic
        }
      }
      Behavior on x {
        NumberAnimation {
          duration: 600
          easing.type: Easing.OutCubic
        }
      }
    }

    Timer {
      id: overlayFadeTimer

      interval: 600

      onTriggered: {
        overlayFlash.opacity = 0;
        root.overlayFlashWidth = 2;
        root.overlayFlashX = root.implicitWidth / 2 - root.overlayFlashWidth / 2;
      }
    }

    Timer {
      id: overlayFlashStartTimer

      interval: 20

      onTriggered: {
        overlayFlash.opacity = 1;
        root.overlayFlashWidth = root.implicitWidth;
        root.overlayFlashX = 0;
        overlayFadeTimer.start();
      }
    }

    Row {
      anchors.centerIn: parent
      spacing: 4

      Text {
        color: root.textColor
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: root.batteryIcon
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        color: root.textColor
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: Math.round(root.percentage * 100) + "%"
      }
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.bottom
      anchors.topMargin: 8
      color: Theme.onHoverColor
      height: tooltipColumn.height + 8
      opacity: batteryArea.containsMouse ? 1 : 0
      radius: Theme.itemRadius
      visible: batteryArea.containsMouse
      width: tooltipColumn.width + 16

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.OutCubic
        }
      }

      Column {
        id: tooltipColumn

        anchors.centerIn: parent
        spacing: 4

        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          text: qsTr("%1").arg(batteryArea.remainingTimeText)
        }

        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          opacity: 0.7
          text: DetectEnv.batteryManager === "ppd" ? (PowerMgmt.ppdText && PowerMgmt.ppdText.length > 0 ? qsTr("PPD: %1").arg(PowerMgmt.ppdText) : PowerMgmt.ppdInfo) : (PowerMgmt.platformProfile && PowerMgmt.platformProfile.length > 0 ? qsTr("Platform: %1").arg(PowerMgmt.platformProfile) : PowerMgmt.platformInfo)
        }

        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          opacity: 0.6
          text: qsTr("CPU: %1 + %2").arg(PowerMgmt.cpuGovernor || qsTr("Unknown")).arg(PowerMgmt.energyPerformance || qsTr("Unknown"))
        }
      }
    }
  }
}
