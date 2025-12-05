pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Services
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.WM
import qs.Config

Item {
  id: root

  required property bool isMainMonitor

  anchors.centerIn: parent
  implicitHeight: card.implicitHeight
  implicitWidth: card.implicitWidth

  transform: Translate {
    id: shakeTransform

  }

  SequentialAnimation {
    id: shakeAnimation

    loops: 1

    NumberAnimation {
      duration: 50
      from: 0
      property: "x"
      target: shakeTransform
      to: 10
    }

    NumberAnimation {
      duration: 50
      property: "x"
      target: shakeTransform
      to: -10
    }

    NumberAnimation {
      duration: 50
      property: "x"
      target: shakeTransform
      to: 10
    }

    NumberAnimation {
      duration: 50
      property: "x"
      target: shakeTransform
      to: 0
    }
  }

  Connections {
    function onAuthStateChanged() {
      if (LockService.authState === "error" || LockService.authState === "fail")
        shakeAnimation.restart();
    }

    target: LockService
  }

  // Card container
  Rectangle {
    id: card

    border.color: Theme.borderMedium
    border.width: Theme.borderWidthThin
    color: Theme.bgCard
    implicitHeight: contentColumn.implicitHeight + Theme.dialogPadding * 2
    implicitWidth: Math.min(root.parent.width * Theme.dialogWidthRatio, Theme.lockCardMaxWidth)
    layer.enabled: true
    radius: Theme.radiusLg

    layer.effect: MultiEffect {
      blurEnabled: true
      blurMax: Theme.shadowBlurLg
      shadowBlur: Theme.shadowBlurMd
      shadowColor: Theme.shadowColor
      shadowEnabled: true
      shadowVerticalOffset: Theme.shadowOffsetY * 4
    }

    ColumnLayout {
      id: contentColumn

      // Lock-specific scale for 2K+/ultrawide
      readonly property real ls: Theme.lockScale

      anchors.centerIn: parent
      spacing: Math.round(Theme.spacingLg * ls)
      width: Math.min(Theme.lockCardContentWidth, parent.width - Theme.dialogPadding * 2)

      // Clock
      ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 0

        OText {
          Layout.alignment: Qt.AlignHCenter
          bold: true
          sizeMultiplier: Theme.baseScale * 5 * contentColumn.ls
          style: Text.Outline
          styleColor: Theme.withOpacity(Theme.bgColor, Theme.opacitySubtle)
          text: TimeService.format("time", TimeService.use24Hour ? "HH:mm" : "h:mm AP")
        }

        OText {
          Layout.alignment: Qt.AlignHCenter
          size: "xl"
          sizeMultiplier: contentColumn.ls
          text: TimeService.format("date", "dddd, MMMM d")
          useActiveColor: false
          weight: Font.Medium
        }
      }

      // User name
      OText {
        Layout.alignment: Qt.AlignHCenter
        bold: true
        opacity: Theme.opacityStrong
        size: "lg"
        sizeMultiplier: contentColumn.ls
        text: MainService.fullName || "User"
        visible: !!text
      }

      // Status chips
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Math.round(Theme.spacingMd * contentColumn.ls)

        Chip {
          visible: !!WeatherService?.currentTemp

          OText {
            size: "lg"
            sizeMultiplier: contentColumn.ls
            text: WeatherService?.weatherInfo().icon ?? ""
          }

          OText {
            bold: true
            size: "sm"
            sizeMultiplier: contentColumn.ls
            text: String(WeatherService?.currentTemp ?? "").split(" ")[0]
          }
        }

        Chip {
          Text {
            font.pixelSize: Math.round(Theme.fontMd * contentColumn.ls)
            text: "💻"
          }

          OText {
            size: "sm"
            sizeMultiplier: contentColumn.ls
            text: MainService.hostname || "localhost"
            useActiveColor: false
          }
        }
      }

      // Password input (main monitor only)
      Rectangle {
        readonly property real ls: contentColumn.ls

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: Math.round(Theme.controlHeightLg * ls)
        Layout.preferredWidth: Math.min(contentColumn.width, Math.round(Theme.controlHeightLg * ls * 6))
        color: Theme.bgInput
        radius: Theme.radiusFull
        visible: root.isMainMonitor

        Behavior on border.color {
          ColorAnimation {
            duration: Theme.animationDuration
          }
        }

        border {
          color: LockService.authState === "fail" ? Theme.critical : LockService.authenticating ? Theme.activeColor : Theme.borderStrong
          width: Theme.borderWidthMedium
        }

        // Lock icon
        Text {
          font.pixelSize: Math.round(Theme.fontMd * parent.ls)
          opacity: Theme.opacityDisabled + 0.2
          text: "🔒"

          anchors {
            left: parent.left
            leftMargin: Math.round(Theme.spacingMd * parent.ls)
            verticalCenter: parent.verticalCenter
          }
        }

        // Password dots
        Row {
          anchors.centerIn: parent
          spacing: Math.round(Theme.spacingXs * contentColumn.ls)
          visible: LockService.passwordBuffer.length > 0

          Repeater {
            model: Math.min(LockService.passwordBuffer.length, 12)

            Rectangle {
              required property int index

              color: Theme.textActiveColor
              height: Math.round(Theme.spacingSm * contentColumn.ls)
              radius: Theme.radiusXs
              width: Math.round(Theme.spacingSm * contentColumn.ls)
            }
          }
        }

        // Status text
        OText {
          anchors.centerIn: parent
          color: LockService.authState === "fail" ? Theme.critical : Theme.textInactiveColor
          size: "sm"
          sizeMultiplier: contentColumn.ls
          text: LockService.statusMessage
          visible: !LockService.passwordBuffer
        }

        // Caps lock indicator
        Rectangle {
          color: Theme.warning
          height: Math.round(Theme.controlHeightXs * contentColumn.ls)
          radius: Theme.radiusSm
          visible: KeyboardLayoutService.capsOn
          width: capsText.implicitWidth + Math.round(Theme.spacingMd * contentColumn.ls)

          anchors {
            right: parent.right
            rightMargin: Math.round(Theme.spacingSm * contentColumn.ls)
            verticalCenter: parent.verticalCenter
          }

          OText {
            id: capsText

            anchors.centerIn: parent
            bold: true
            color: Theme.bgColor
            size: "xs"
            sizeMultiplier: contentColumn.ls
            text: "CAPS"
          }
        }
      }

      // Footer info (main monitor only)
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        opacity: Theme.opacitySolid
        spacing: Math.round(Theme.spacingSm * contentColumn.ls)
        visible: root.isMainMonitor

        // Battery
        RowLayout {
          spacing: Math.round(Theme.spacingXs * contentColumn.ls)
          visible: BatteryService.isLaptopBattery

          Text {
            font.pixelSize: Math.round(Theme.fontSm * contentColumn.ls)
            text: BatteryService.isCharging ? "⚡" : "🔋"
          }

          OText {
            size: "sm"
            sizeMultiplier: contentColumn.ls
            text: BatteryService.percentage + "%"
            useActiveColor: false
          }
        }

        Divider {
          visible: BatteryService.isLaptopBattery
        }

        OText {
          size: "sm"
          sizeMultiplier: contentColumn.ls
          text: "Enter to unlock"
          useActiveColor: false
        }

        Divider {
          visible: !!KeyboardLayoutService.currentLayout
        }

        OText {
          size: "sm"
          sizeMultiplier: contentColumn.ls
          text: KeyboardLayoutService.currentLayout
          useActiveColor: false
          visible: !!KeyboardLayoutService.currentLayout
          weight: Font.Medium
        }

        Divider {
          visible: NetworkService.ready
        }

        // Network
        RowLayout {
          readonly property string link: NetworkService.linkType || "disconnected"
          readonly property string ssid: NetworkService.wifiAps.find(a => a?.connected)?.ssid ?? ""

          spacing: Math.round(Theme.spacingXs * contentColumn.ls)
          visible: NetworkService.ready

          Text {
            font.pixelSize: Math.round(Theme.fontSm * contentColumn.ls)
            text: parent.link === "ethernet" ? "🔌" : parent.link === "wifi" ? "📶" : "📵"
          }

          OText {
            size: "sm"
            sizeMultiplier: contentColumn.ls
            text: parent.link === "ethernet" ? "Ethernet" : parent.link === "wifi" ? parent.ssid : "Offline"
            useActiveColor: false
          }
        }
      }
    }
  }

  // Chip component
  component Chip: Rectangle {
    default property alias content: chipRow.children

    Layout.preferredHeight: Math.round(Theme.controlHeightMd * contentColumn.ls)
    Layout.preferredWidth: chipRow.implicitWidth + Math.round(Theme.spacingLg * contentColumn.ls)
    border.color: Theme.borderSubtle
    color: Theme.bgSubtle
    radius: Theme.radiusSm

    RowLayout {
      id: chipRow

      anchors.centerIn: parent
      spacing: Math.round(Theme.spacingXs * contentColumn.ls)
    }
  }

  // Divider component
  component Divider: Rectangle {
    color: Theme.textInactiveColor
    height: Math.round(Theme.spacingMd * contentColumn.ls)
    width: Theme.borderWidthThin
  }
}
