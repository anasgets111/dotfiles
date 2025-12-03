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

      anchors.centerIn: parent
      spacing: Theme.spacingLg
      width: Math.min(Theme.lockCardContentWidth, parent.width - Theme.dialogPadding * 2)

      // Clock
      ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 0

        OText {
          Layout.alignment: Qt.AlignHCenter
          bold: true
          sizeMultiplier: Theme.baseScale * 5
          style: Text.Outline
          styleColor: Theme.withOpacity(Theme.bgColor, Theme.opacitySubtle)
          text: TimeService.format("time", TimeService.use24Hour ? "HH:mm" : "h:mm AP")
        }

        OText {
          Layout.alignment: Qt.AlignHCenter
          size: "xl"
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
        text: MainService.fullName || "User"
        visible: !!text
      }

      // Status chips
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Theme.spacingMd

        Chip {
          visible: !!WeatherService?.currentTemp

          OText {
            size: "lg"
            text: WeatherService?.weatherInfo().icon ?? ""
          }

          OText {
            bold: true
            size: "sm"
            text: String(WeatherService?.currentTemp ?? "").split(" ")[0]
          }
        }

        Chip {
          Text {
            font.pixelSize: Theme.fontMd
            text: "💻"
          }

          OText {
            size: "sm"
            text: MainService.hostname || "localhost"
            useActiveColor: false
          }
        }
      }

      // Password input (main monitor only)
      Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: Theme.controlHeightLg
        Layout.preferredWidth: Math.min(contentColumn.width, Theme.controlHeightLg * 6)
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
          font.pixelSize: Theme.fontMd
          opacity: Theme.opacityDisabled + 0.2
          text: "🔒"

          anchors {
            left: parent.left
            leftMargin: Theme.spacingMd
            verticalCenter: parent.verticalCenter
          }
        }

        // Password dots
        Row {
          anchors.centerIn: parent
          spacing: Theme.spacingXs
          visible: LockService.passwordBuffer.length > 0

          Repeater {
            model: Math.min(LockService.passwordBuffer.length, 12)

            Rectangle {
              required property int index

              color: Theme.textActiveColor
              height: Theme.spacingSm
              radius: Theme.radiusXs
              width: Theme.spacingSm
            }
          }
        }

        // Status text
        OText {
          anchors.centerIn: parent
          color: LockService.authState === "fail" ? Theme.critical : Theme.textInactiveColor
          size: "sm"
          text: LockService.statusMessage
          visible: !LockService.passwordBuffer
        }

        // Caps lock indicator
        Rectangle {
          color: Theme.warning
          height: Theme.controlHeightXs
          radius: Theme.radiusSm
          visible: KeyboardLayoutService.capsOn
          width: capsText.implicitWidth + Theme.spacingMd

          anchors {
            right: parent.right
            rightMargin: Theme.spacingSm
            verticalCenter: parent.verticalCenter
          }

          OText {
            id: capsText

            anchors.centerIn: parent
            bold: true
            color: Theme.bgColor
            size: "xs"
            text: "CAPS"
          }
        }
      }

      // Footer info (main monitor only)
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        opacity: Theme.opacitySolid
        spacing: Theme.spacingSm
        visible: root.isMainMonitor

        // Battery
        RowLayout {
          spacing: Theme.spacingXs
          visible: BatteryService.isLaptopBattery

          Text {
            font.pixelSize: Theme.fontSm
            text: BatteryService.isCharging ? "⚡" : "🔋"
          }

          OText {
            size: "sm"
            text: BatteryService.percentage + "%"
            useActiveColor: false
          }
        }

        Divider {
          visible: BatteryService.isLaptopBattery
        }

        OText {
          size: "sm"
          text: "Enter to unlock"
          useActiveColor: false
        }

        Divider {
          visible: !!KeyboardLayoutService.currentLayout
        }

        OText {
          size: "sm"
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

          spacing: Theme.spacingXs
          visible: NetworkService.ready

          Text {
            font.pixelSize: Theme.fontSm
            text: parent.link === "ethernet" ? "🔌" : parent.link === "wifi" ? "📶" : "📵"
          }

          OText {
            size: "sm"
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

    Layout.preferredHeight: Theme.controlHeightMd
    Layout.preferredWidth: chipRow.implicitWidth + Theme.spacingLg
    border.color: Theme.borderSubtle
    color: Theme.bgSubtle
    radius: Theme.radiusSm

    RowLayout {
      id: chipRow

      anchors.centerIn: parent
      spacing: Theme.spacingXs
    }
  }

  // Divider component
  component Divider: Rectangle {
    color: Theme.textInactiveColor
    height: Theme.spacingMd
    width: Theme.borderWidthThin
  }
}
