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
  readonly property real lockScale: Theme.lockScale

  anchors.centerIn: parent
  implicitHeight: card.implicitHeight
  implicitWidth: card.implicitWidth

  transform: Translate {
    id: shakeTransform

  }

  SequentialAnimation {
    id: shakeAnimation

    loops: 1

    PropertyAnimation {
      duration: 50
      from: 0
      property: "x"
      target: shakeTransform
      to: 10
    }

    PropertyAnimation {
      duration: 50
      property: "x"
      target: shakeTransform
      to: -10
    }

    PropertyAnimation {
      duration: 50
      property: "x"
      target: shakeTransform
      to: 10
    }

    PropertyAnimation {
      duration: 50
      property: "x"
      target: shakeTransform
      to: 0
    }
  }

  Connections {
    function onAuthStateChanged() {
      if (LockService.authState === LockService.authStates.error || LockService.authState === LockService.authStates.fail)
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

      anchors.centerIn: parent
      spacing: Math.round(Theme.spacingLg * root.lockScale)
      width: Math.min(Theme.lockCardContentWidth, parent.width - Theme.dialogPadding * 2)

      // Clock
      ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 0

        OText {
          Layout.alignment: Qt.AlignHCenter
          bold: true
          sizeMultiplier: Theme.baseScale * 5 * root.lockScale
          style: Text.Outline
          styleColor: Theme.withOpacity(Theme.bgColor, Theme.opacitySubtle)
          text: TimeService.format("time", TimeService.use24Hour ? "HH:mm" : "h:mm AP")
        }

        OText {
          Layout.alignment: Qt.AlignHCenter
          size: "xl"
          sizeMultiplier: root.lockScale
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
        sizeMultiplier: root.lockScale
        text: MainService.fullName || "User"
        visible: !!text
      }

      // Status chips
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Math.round(Theme.spacingMd * root.lockScale)

        Chip {
          visible: !!WeatherService?.currentTemp

          OText {
            size: "lg"
            sizeMultiplier: root.lockScale
            text: WeatherService?.weatherInfo().icon ?? ""
          }

          OText {
            bold: true
            size: "sm"
            sizeMultiplier: root.lockScale
            text: String(WeatherService?.currentTemp ?? "").split(" ")[0]
          }
        }

        Chip {
          Text {
            font.pixelSize: Math.round(Theme.fontMd * root.lockScale)
            text: "💻"
          }

          OText {
            size: "sm"
            sizeMultiplier: root.lockScale
            text: MainService.hostname || "localhost"
            useActiveColor: false
          }
        }
      }

      // Password input (main monitor only)
      Rectangle {
        id: passwordBox

        readonly property bool hasPassword: passwordLength > 0
        readonly property int passwordLength: LockService.passwordBuffer.length

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: Math.round(Theme.controlHeightLg * root.lockScale)
        Layout.preferredWidth: Math.min(contentColumn.width, Math.round(Theme.controlHeightLg * root.lockScale * 6))
        color: Theme.bgInput
        radius: Theme.radiusFull
        visible: root.isMainMonitor

        Behavior on border.color {
          ColorAnimation {
            duration: Theme.animationDuration
          }
        }

        border {
          color: LockService.authState === LockService.authStates.fail ? Theme.critical : LockService.authenticating ? Theme.activeColor : Theme.borderStrong
          width: Theme.borderWidthMedium
        }

        // Lock icon
        Text {
          font.pixelSize: Math.round(Theme.fontMd * root.lockScale)
          opacity: Theme.opacityDisabled + 0.2
          text: "🔒"

          anchors {
            left: parent.left
            leftMargin: Math.round(Theme.spacingMd * root.lockScale)
            verticalCenter: parent.verticalCenter
          }
        }

        // Password dots
        Row {
          anchors.centerIn: parent
          spacing: Math.round(Theme.spacingXs * root.lockScale)
          visible: passwordBox.hasPassword

          Repeater {
            model: Math.min(passwordBox.passwordLength, 12)

            Rectangle {
              required property int index

              color: Theme.textActiveColor
              height: Math.round(Theme.spacingSm * root.lockScale)
              radius: Theme.radiusXs
              width: Math.round(Theme.spacingSm * root.lockScale)
            }
          }
        }

        // Status text
        OText {
          anchors.centerIn: parent
          color: LockService.authState === LockService.authStates.fail ? Theme.critical : Theme.textInactiveColor
          size: "sm"
          sizeMultiplier: root.lockScale
          text: LockService.statusMessage
          visible: !passwordBox.hasPassword
        }

        // Caps lock indicator
        Rectangle {
          color: Theme.warning
          height: Math.round(Theme.controlHeightXs * root.lockScale)
          radius: Theme.radiusSm
          visible: KeyboardLayoutService.capsOn
          width: capsText.implicitWidth + Math.round(Theme.spacingMd * root.lockScale)

          anchors {
            right: parent.right
            rightMargin: Math.round(Theme.spacingSm * root.lockScale)
            verticalCenter: parent.verticalCenter
          }

          OText {
            id: capsText

            anchors.centerIn: parent
            bold: true
            color: Theme.bgColor
            size: "xs"
            sizeMultiplier: root.lockScale
            text: "CAPS"
          }
        }
      }

      // Footer info (main monitor only)
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        opacity: Theme.opacitySolid
        spacing: Math.round(Theme.spacingSm * root.lockScale)
        visible: root.isMainMonitor

        // Battery
        RowLayout {
          spacing: Math.round(Theme.spacingXs * root.lockScale)
          visible: BatteryService.isLaptopBattery

          Text {
            color: Theme.textActiveColor
            font.pixelSize: Math.round(Theme.fontSm * root.lockScale)
            text: BatteryService.isCharging ? "⚡" : "🔋"
          }

          OText {
            color: Theme.textActiveColor
            size: "sm"
            sizeMultiplier: root.lockScale
            text: BatteryService.percentage + "%"
            useActiveColor: false
          }
        }

        Divider {
          visible: BatteryService.isLaptopBattery
        }

        OText {
          color: Theme.textActiveColor
          size: "sm"
          sizeMultiplier: root.lockScale
          text: "Enter to unlock"
          useActiveColor: false
        }

        Divider {
          visible: !!KeyboardLayoutService.currentLayout
        }

        OText {
          color: Theme.textActiveColor
          size: "sm"
          sizeMultiplier: root.lockScale
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

          spacing: Math.round(Theme.spacingXs * root.lockScale)
          visible: NetworkService.ready

          Text {
            color: Theme.textActiveColor
            font.pixelSize: Math.round(Theme.fontSm * root.lockScale)
            text: parent.link === "ethernet" ? "🖧" : parent.link === "wifi" ? "📶" : "📵"
          }

          OText {
            color: Theme.textActiveColor
            size: "sm"
            sizeMultiplier: root.lockScale
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

    Layout.preferredHeight: Math.round(Theme.controlHeightMd * root.lockScale)
    Layout.preferredWidth: chipRow.implicitWidth + Math.round(Theme.spacingLg * root.lockScale)
    border.color: Theme.borderSubtle
    color: Theme.bgSubtle
    radius: Theme.radiusFull

    RowLayout {
      id: chipRow

      anchors.centerIn: parent
      spacing: Math.round(Theme.spacingXs * root.lockScale)
    }
  }

  // Divider component
  component Divider: Rectangle {
    color: Theme.textInactiveColor
    height: Math.round(Theme.spacingMd * root.lockScale)
    width: Theme.borderWidthThin
  }
}
