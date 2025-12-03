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

  // Shared colors - using Theme tokens
  readonly property color cardBg: Theme.bgCard
  readonly property color cardBorder: Theme.borderMedium
  readonly property color chipBg: Theme.withOpacity(Theme.bgColor, 0.5)
  readonly property color chipBorder: Theme.withOpacity(Theme.borderColor, 0.3)
  readonly property color inputBg: Theme.bgInput
  readonly property color inputBorder: Theme.borderStrong
  required property bool isMainMonitor

  anchors.centerIn: parent
  height: contentColumn.implicitHeight + Theme.dialogPadding * 3
  width: Math.min(parent.width * 0.9, 500)

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

  // Background Card
  Rectangle {
    anchors.fill: parent
    border.color: root.cardBorder
    border.width: 1
    color: root.cardBg
    layer.enabled: true
    radius: Theme.itemRadius * 2

    layer.effect: MultiEffect {
      blur: 0.2
      blurEnabled: true
      blurMax: Theme.shadowBlurLg
      shadowBlur: Theme.shadowBlurMd
      shadowColor: Theme.shadowColor
      shadowEnabled: true
      shadowVerticalOffset: 10
    }
  }

  // Content
  ColumnLayout {
    id: contentColumn

    anchors.centerIn: parent
    spacing: Theme.spacingXl
    width: parent.width - Theme.dialogPadding * 3

    // 1. Clock Section
    ColumnLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: -Math.round(Theme.baseScale * 8)

      OText {
        Layout.alignment: Qt.AlignHCenter
        bold: true
        sizeMultiplier: Theme.baseScale * 5
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.1)
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

    // 2. User Info
    OText {
      Layout.alignment: Qt.AlignHCenter
      bold: true
      opacity: 0.8
      size: "lg"
      text: MainService.fullName || "User"
      visible: !!text
    }

    // 3. Status Chips (Weather, Host)
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
          font.pixelSize: Theme.fontSize
          text: "💻"
        }

        OText {
          size: "sm"
          text: MainService.hostname || "localhost"
          useActiveColor: false
        }
      }
    }

    // 4. Password Input Area (main monitor only)
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: Theme.itemHeight * 1.4
      Layout.topMargin: Theme.spacingSm
      visible: root.isMainMonitor

      Rectangle {
        anchors.centerIn: parent
        border.color: LockService.authState === "fail" ? Theme.critical : LockService.authenticating ? Theme.activeColor : root.inputBorder
        border.width: 2
        color: root.inputBg
        height: Theme.itemHeight * 1.3
        radius: height / 2
        width: Math.min(parent.width, Theme.itemHeight * 8)

        Behavior on border.color {
          ColorAnimation {
            duration: Theme.animationDuration
          }
        }

        // Lock icon
        Text {
          font.pixelSize: Theme.fontSize
          opacity: 0.7
          text: "🔒"

          anchors {
            left: parent.left
            leftMargin: Theme.fontSize
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
              height: 8
              radius: Theme.radiusXs
              width: 8
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
          height: Theme.controlHeightSm
          radius: Theme.itemRadius
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
    }

    // 5. Footer Info (main monitor only)
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      opacity: 0.6
      spacing: Theme.fontSize
      visible: root.isMainMonitor

      RowLayout {
        spacing: Theme.spacingXs
        visible: BatteryService.isLaptopBattery

        Text {
          font.pixelSize: Theme.fontSize - 3
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

      RowLayout {
        readonly property string link: NetworkService.linkType || "disconnected"
        readonly property string ssid: NetworkService.wifiAps.find(a => a?.connected)?.ssid ?? ""

        spacing: Theme.spacingXs
        visible: NetworkService.ready

        Text {
          font.pixelSize: Theme.fontSize - 3
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

  // Chip component for status indicators
  component Chip: Rectangle {
    default property alias content: chipContent.children

    Layout.preferredHeight: Theme.itemHeight
    Layout.preferredWidth: chipContent.implicitWidth + Theme.fontSize * 1.5
    border.color: root.chipBorder
    color: root.chipBg
    radius: Theme.itemRadius

    RowLayout {
      id: chipContent

      anchors.centerIn: parent
      spacing: Theme.spacingXs
    }
  }

  // Divider component for footer
  component Divider: Rectangle {
    color: Theme.textInactiveColor
    height: Theme.spacingMd
    width: 1
  }
}
