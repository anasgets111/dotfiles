pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Config
import qs.Services.Core

Item {
  id: root

  // Colors/icons derived from BatteryService state
  readonly property color batteryColor: percentage <= 0.1 ? Theme.critical : percentage <= 0.2 ? Theme.warning : Theme.activeColor
  readonly property string batteryIcon: {
    if (BatteryService.isCharging)
      return "";
    if (BatteryService.isPendingCharge)
      return "󰂄";
    const icons = ["", "", "", "", ""];
    return icons[Math.min(Math.floor(percentage * 5), 4)];
  }
  readonly property color bgColor: Theme.inactiveColor
  readonly property bool isPluggedIn: BatteryService.isPluggedIn

  // flash animation state
  property real overlayFlashWidth: 2
  property real overlayFlashX: implicitWidth / 2 - overlayFlashWidth / 2
  // normalized 0..1 from service
  property real percentage: BatteryService.percentageFraction

  // Local alias to avoid unqualified access warnings
  readonly property var power: PowerManagementService
  readonly property color textColor: Theme.textContrast(percentage > 0.6 ? batteryColor : bgColor)
  property int widthPhase: 0

  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.batteryPillWidth
  visible: BatteryService.isReady

  onIsPluggedInChanged: if (isPluggedIn) {
    if (widthTimer.running)
      widthTimer.stop();
    widthPhase = 1;
    widthTimer.start();
  }

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
      if (BatteryService.isFullyCharged)
        return "Fully Charged";
      if (BatteryService.isPendingCharge)
        return "Charge Limit Reached";
      if (!BatteryService.isCharging && BatteryService.percentage === 100)
        return "Connected";
      // Prefer service-provided strings
      return BatteryService.isCharging ? BatteryService.timeToFullText : BatteryService.timeToEmptyText;
    }

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: {
      // Toggle power profile via service if available
      try {
        if (root.power && root.power.isReady) {
          const next = root.power.currentProfile === "performance" ? "powersave" : "performance";
          root.power.setProfile(next);
        }
      } catch (_e) {}
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
        text: BatteryService.percentage + "%"
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
          text: (BatteryService.isACPowered ? qsTr("Power: AC") : qsTr("Power: Battery")) + (root.power && root.power.isReady ? qsTr(" · Profile: %1").arg(root.power.currentProfile) : "") + (root.power && root.power.hasPPD ? (" · " + (root.power.ppdText && root.power.ppdText.length > 0 ? qsTr("PPD: %1").arg(root.power.ppdText) : root.power.ppdInfo)) : (root.power && root.power.platformProfile && root.power.platformProfile.length > 0 ? (" · " + qsTr("Platform: %1").arg(root.power.platformProfile)) : (root.power ? (" · " + root.power.platformInfo) : "")))
        }
        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          opacity: 0.6
          text: qsTr("CPU: %1 + %2").arg(root.power && root.power.cpuGovernor ? root.power.cpuGovernor : qsTr("Unknown")).arg(root.power && root.power.energyPerformance ? root.power.energyPerformance : qsTr("Unknown"))
        }
      }
    }
  }
}
