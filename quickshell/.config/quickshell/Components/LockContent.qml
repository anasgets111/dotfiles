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

  readonly property var colors: LockService.theme
  required property bool isMainMonitor

  function rgba(color, alpha: real): color {
    return Qt.rgba(color.r, color.g, color.b, alpha);
  }

  anchors.centerIn: parent
  height: contentColumn.implicitHeight + 60
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

  // --- Background Card ---
  Rectangle {
    anchors.fill: parent
    border.color: root.rgba(root.colors.surface1, 0.4)
    border.width: 1
    color: root.rgba(root.colors.base, 0.6)
    layer.enabled: true
    radius: 32

    layer.effect: MultiEffect {
      blur: 0.2
      blurEnabled: true
      blurMax: 32
      shadowBlur: 20
      shadowColor: Qt.rgba(0, 0, 0, 0.2)
      shadowEnabled: true
      shadowVerticalOffset: 10
    }
  }

  // --- Content ---
  ColumnLayout {
    id: contentColumn

    anchors.centerIn: parent
    spacing: 24
    width: parent.width - 60

    // 1. Clock Section
    ColumnLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: -10

      Text {
        Layout.alignment: Qt.AlignHCenter
        color: Theme.textActiveColor
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: 86
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.1)
        text: TimeService.format("time", TimeService.use24Hour ? "HH:mm" : "hh:mm")
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        color: Theme.textInactiveColor
        font.family: Theme.fontFamily
        font.pixelSize: 22
        font.weight: Font.Medium
        text: TimeService.format("date", "dddd, MMMM d")
      }
    }

    // 2. User Info
    Text {
      Layout.alignment: Qt.AlignHCenter
      color: Theme.textActiveColor
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: 18
      opacity: 0.8
      text: MainService.fullName || "User"
      visible: !!text
    }

    // 3. Status Chips (Weather, Host)
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 12

      Chip {
        visible: !!WeatherService

        Text {
          color: Theme.textActiveColor
          font.pixelSize: 18
          text: WeatherService?.weatherInfo().icon ?? ""
        }

        Text {
          color: Theme.textActiveColor
          font.bold: true
          font.family: Theme.fontFamily
          font.pixelSize: 14
          text: String(WeatherService?.currentTemp ?? "").split(" ")[0]
        }
      }

      Chip {
        Text {
          font.pixelSize: 16
          text: "💻"
        }

        Text {
          color: Theme.textInactiveColor
          font.family: Theme.fontFamily
          font.pixelSize: 14
          text: MainService.hostname || "localhost"
        }
      }
    }

    // 4. Password Input Area (main monitor only)
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: 60
      Layout.topMargin: 10
      visible: root.isMainMonitor

      Rectangle {
        anchors.centerIn: parent
        border.color: LockService.authState === "fail" ? Theme.critical : LockService.authenticating ? Theme.activeColor : root.rgba(root.colors.surface2, 0.5)
        border.width: 2
        color: root.rgba(root.colors.surface0, 0.8)
        height: 50
        radius: 25
        width: Math.min(parent.width, 300)

        Behavior on border.color {
          ColorAnimation {
            duration: 150
          }
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          font.pixelSize: 18
          opacity: 0.7
          text: "🔒"
        }

        Row {
          anchors.centerIn: parent
          spacing: 6
          visible: LockService.passwordBuffer.length > 0

          Repeater {
            model: Math.min(LockService.passwordBuffer.length, 12)

            Rectangle {
              required property int index

              color: Theme.textActiveColor
              height: 8
              radius: 4
              width: 8
            }
          }
        }

        Text {
          anchors.centerIn: parent
          color: LockService.authState === "fail" ? Theme.critical : Theme.textInactiveColor
          font.family: Theme.fontFamily
          font.pixelSize: 14
          text: LockService.statusMessage
          visible: !LockService.passwordBuffer
        }

        Rectangle {
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          color: Theme.critical
          height: 24
          radius: 12
          visible: KeyboardLayoutService.capsOn
          width: 24

          Text {
            anchors.centerIn: parent
            color: root.colors.base
            font.bold: true
            font.pixelSize: 14
            text: "A"
          }
        }
      }
    }

    // 5. Footer Info (main monitor only)
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      opacity: 0.6
      spacing: 16
      visible: root.isMainMonitor

      RowLayout {
        spacing: 4
        visible: BatteryService.isLaptopBattery

        Text {
          color: Theme.textInactiveColor
          font.pixelSize: 12
          text: BatteryService.isCharging ? "⚡" : "🔋"
        }

        Text {
          color: Theme.textInactiveColor
          font.family: Theme.fontFamily
          font.pixelSize: 12
          text: BatteryService.percentage + "%"
        }
      }

      Divider {
        visible: BatteryService.isLaptopBattery
      }

      Text {
        color: Theme.textInactiveColor
        font.family: Theme.fontFamily
        font.pixelSize: 12
        text: "Enter to unlock"
      }

      Divider {
      }

      Text {
        color: Theme.textInactiveColor
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: 12
        text: KeyboardLayoutService.currentLayout
        visible: !!KeyboardLayoutService.currentLayout
      }

      Divider {
        visible: NetworkService.ready
      }

      RowLayout {
        readonly property string link: NetworkService.linkType || "disconnected"
        readonly property string ssid: {
          const ap = NetworkService.wifiAps.find(a => a?.connected);
          if (ap?.ssid)
            return String(ap.ssid);
          const active = NetworkService.chooseActiveDevice(NetworkService.deviceList);
          return (active?.type === "wifi") ? (active.connectionName || "") : "";
        }

        spacing: 4
        visible: NetworkService.ready

        Text {
          color: Theme.textInactiveColor
          font.pixelSize: 12
          text: parent.link === "ethernet" ? "󰈀" : (parent.link === "wifi" ? "󰤨" : "󰤭")
        }

        Text {
          color: Theme.textInactiveColor
          font.family: Theme.fontFamily
          font.pixelSize: 12
          text: parent.link === "ethernet" ? "Ethernet" : (parent.link === "wifi" ? parent.ssid : "Offline")
        }
      }
    }
  }

  // Chip component for status indicators
  component Chip: Rectangle {
    default property alias content: chipContent.children

    Layout.preferredHeight: 36
    Layout.preferredWidth: chipContent.implicitWidth + 24
    border.color: root.rgba(root.colors.surface1, 0.3)
    color: root.rgba(root.colors.surface0, 0.5)
    radius: 18

    RowLayout {
      id: chipContent

      anchors.centerIn: parent
      spacing: 8
    }
  }

  // Divider component for footer
  component Divider: Rectangle {
    color: Theme.textInactiveColor
    height: 12
    width: 1
  }
}
