pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Components
import qs.Config
import qs.Services.Core

Item {
  id: root

  readonly property color batteryColor: percentage <= 0.1 ? Theme.critical : percentage <= 0.2 ? Theme.warning : Theme.activeColor
  readonly property string batteryIcon: {
    if (BatteryService.isPendingCharge)
      return "󰂄";
    if (BatteryService.isACPowered)
      return "";
    const icons = ["", "", "", "", ""];
    return icons[Math.min(Math.floor(percentage * 5), 4)];
  }
  readonly property color bgColor: Theme.inactiveColor
  readonly property bool isPluggedIn: BatteryService.isACPowered
  readonly property real percentage: BatteryService.percentageFraction
  readonly property var power: PowerManagementService
  readonly property string powerInfoText: {
    const src = BatteryService.isACPowered ? qsTr("Power: AC") : qsTr("Power: Battery");
    const ppd = power?.hasPPD && power?.ppdProfile ? qsTr(" · PPD: %1").arg(power.ppdProfile) : "";
    const platform = !power?.hasPPD && power?.platformProfile ? qsTr(" · Platform: %1").arg(power.platformProfile) : "";
    return src + (ppd || platform);
  }
  readonly property string statusText: {
    if (BatteryService.isFullyCharged)
      return qsTr("Fully Charged");
    if (BatteryService.isPendingCharge)
      return qsTr("Charge Limit Reached");
    if (BatteryService.isACPowered && BatteryService.percentage === 100)
      return qsTr("Connected");
    return BatteryService.isACPowered ? BatteryService.timeToFullText : BatteryService.timeToEmptyText;
  }
  readonly property color textColor: Theme.textContrast(percentage > 0.6 ? batteryColor : bgColor)

  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.batteryPillWidth
  visible: BatteryService.isReady

  onIsPluggedInChanged: if (isPluggedIn)
    plugFlash.restart()

  Rectangle {
    anchors.fill: parent
    color: root.bgColor
    radius: height / 2
  }

  ClippingRectangle {
    id: fillClip

    anchors.fill: parent
    color: "transparent"
    radius: height / 2

    Rectangle {
      id: fillRect

      color: root.batteryColor
      width: fillClip.width * root.percentage

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

  SequentialAnimation {
    id: plugFlash

    loops: 2

    PropertyAction {
      property: "opacity"
      target: fillRect
      value: 0
    }

    PauseAnimation {
      duration: Theme.animationFast
    }

    PropertyAction {
      property: "opacity"
      target: fillRect
      value: 1
    }

    PauseAnimation {
      duration: Theme.animationFast
    }
  }

  MouseArea {
    id: mouseArea

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: clickFlash.restart()

    Rectangle {
      anchors.fill: parent
      color: mouseArea.containsMouse ? Theme.onHoverColor : "transparent"
      radius: height / 2

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationFast
          easing.type: Easing.OutCubic
        }
      }
    }

    Rectangle {
      id: flashOverlay

      anchors.fill: parent
      color: Theme.warning
      opacity: 0
      radius: height / 2
    }

    SequentialAnimation {
      id: clickFlash

      NumberAnimation {
        duration: 50
        property: "opacity"
        target: flashOverlay
        to: 1
      }

      NumberAnimation {
        duration: 400
        easing.type: Easing.OutCubic
        property: "opacity"
        target: flashOverlay
        to: 0
      }
    }

    Row {
      anchors.centerIn: parent
      spacing: Theme.spacingXs

      OText {
        bold: true
        color: root.textColor
        text: root.batteryIcon
      }

      OText {
        anchors.verticalCenter: parent.verticalCenter
        bold: true
        color: root.textColor
        text: BatteryService.percentage + "%"
      }
    }

    Rectangle {
      color: Theme.onHoverColor
      height: tooltipCol.height + Theme.spacingSm
      opacity: mouseArea.containsMouse ? 1 : 0
      radius: Theme.itemRadius
      visible: mouseArea.containsMouse
      width: tooltipCol.width + Theme.spacingLg

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.OutCubic
        }
      }

      anchors {
        horizontalCenter: parent.horizontalCenter
        top: parent.bottom
        topMargin: Theme.spacingSm
      }

      Column {
        id: tooltipCol

        anchors.centerIn: parent
        spacing: Theme.spacingXs

        OText {
          color: Theme.textContrast(Theme.onHoverColor)
          text: root.statusText
        }

        // Power info
        OText {
          color: Theme.textContrast(Theme.onHoverColor)
          opacity: 0.7
          text: root.powerInfoText
        }

        OText {
          color: Theme.textContrast(Theme.onHoverColor)
          opacity: 0.6
          text: qsTr("CPU: %1 + %2").arg(root.power?.cpuGovernor ?? "Unknown").arg(root.power?.energyPerformance ?? "Unknown")
        }
      }
    }
  }
}
