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

  // Theme aliases
  readonly property var cTheme: LockService.theme
  readonly property color colBase: cTheme.base
  readonly property color colSurface0: cTheme.surface0
  readonly property color colSurface1: cTheme.surface1
  readonly property color colSurface2: cTheme.surface2
  required property bool isMainMonitor

  anchors.centerIn: parent
  height: contentColumn.implicitHeight + 60
  width: Math.min(parent.width * 0.9, 500)

  transform: Translate {
    id: shakeTransform

  }

  SequentialAnimation {
    id: shakeAnimation

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
    border.color: Qt.rgba(root.colSurface1.r, root.colSurface1.g, root.colSurface1.b, 0.4)
    border.width: 1
    color: Qt.rgba(root.colBase.r, root.colBase.g, root.colBase.b, 0.6)
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
      visible: text.length > 0
    }

    // 3. Status Chips (Weather, Host)
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 12

      // Weather Chip
      Rectangle {
        Layout.preferredHeight: 36
        Layout.preferredWidth: weatherRow.implicitWidth + 24
        border.color: Qt.rgba(root.colSurface1.r, root.colSurface1.g, root.colSurface1.b, 0.3)
        color: Qt.rgba(root.colSurface0.r, root.colSurface0.g, root.colSurface0.b, 0.5)
        radius: 18
        visible: WeatherService

        RowLayout {
          id: weatherRow

          anchors.centerIn: parent
          spacing: 8

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
      }

      // Host Chip
      Rectangle {
        Layout.preferredHeight: 36
        Layout.preferredWidth: hostRow.implicitWidth + 24
        border.color: Qt.rgba(root.colSurface1.r, root.colSurface1.g, root.colSurface1.b, 0.3)
        color: Qt.rgba(root.colSurface0.r, root.colSurface0.g, root.colSurface0.b, 0.5)
        radius: 18

        RowLayout {
          id: hostRow

          anchors.centerIn: parent
          spacing: 8

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
    }

    // 4. Password Input Area (main monitor only)
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: 60
      Layout.topMargin: 10
      visible: root.isMainMonitor

      Rectangle {
        anchors.centerIn: parent
        border.color: LockService.authState === "fail" ? Theme.critical : LockService.authenticating ? Theme.activeColor : Qt.rgba(root.colSurface2.r, root.colSurface2.g, root.colSurface2.b, 0.5)
        border.width: 2
        color: Qt.rgba(root.colSurface0.r, root.colSurface0.g, root.colSurface0.b, 0.8)
        height: 50
        radius: 25
        width: Math.min(parent.width, 300)

        Behavior on border.color {
          ColorAnimation {
            duration: 150
          }
        }

        // Lock Icon
        Text {
          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          font.pixelSize: 18
          opacity: 0.7
          text: "🔒"
        }

        // Password Dots
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

        // Status Text
        Text {
          anchors.centerIn: parent
          color: LockService.authState === "fail" ? Theme.critical : Theme.textInactiveColor
          font.family: Theme.fontFamily
          font.pixelSize: 14
          text: LockService.statusMessage
          visible: LockService.passwordBuffer.length === 0
        }

        // Caps Lock Indicator
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
            color: root.colBase
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

      // Battery
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

      Rectangle {
        color: Theme.textInactiveColor
        height: 12
        visible: BatteryService.isLaptopBattery
        width: 1
      }

      Text {
        color: Theme.textInactiveColor
        font.family: Theme.fontFamily
        font.pixelSize: 12
        text: "Enter to unlock"
      }

      Rectangle {
        color: Theme.textInactiveColor
        height: 12
        width: 1
      }

      Text {
        color: Theme.textInactiveColor
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: 12
        text: KeyboardLayoutService.currentLayout
        visible: KeyboardLayoutService.currentLayout.length > 0
      }

      Rectangle {
        color: Theme.textInactiveColor
        height: 12
        visible: NetworkService.ready
        width: 1
      }

      // Network
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
}
