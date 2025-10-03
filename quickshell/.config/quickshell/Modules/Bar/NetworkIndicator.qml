pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.Config
import qs.Components
import qs.Services.Core

Item {
  id: root

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)
  visible: !!NetworkService && NetworkService.ready

  // State properties
  readonly property bool ready: NetworkService && NetworkService.ready
  readonly property string link: ready ? (NetworkService.linkType || "disconnected") : "disconnected"
  readonly property var aps: ready ? (NetworkService.wifiAps || []) : []
  readonly property var ap: aps.find(ap => ap?.connected) || null
  readonly property var active: ready ? NetworkService.chooseActiveDevice(NetworkService.deviceList || []) : null
  readonly property string ssid: ap?.ssid || (active?.type === "wifi" ? active.connectionName || "" : "")
  readonly property int strength: ap?.signal ?? 0
  readonly property string band: ap?.band || ""
  readonly property string netIcon: !ready ? "󰤭" : link === "ethernet" ? "󰈀" : link === "wifi" ? NetworkService.getWifiIcon(band, strength) : NetworkService.wifiRadioEnabled ? "󰤭" : "󰤮"

  // Tooltip content
  readonly property string title: !ready ? qsTr("Network: initializing…") : link === "ethernet" ? qsTr("Ethernet") : link === "wifi" ? `${ssid || qsTr("Wi-Fi")} (${strength > 0 ? strength + "%" : "--"})${band ? qsTr(" • %1 GHz").arg(band) : ""}` : NetworkService.wifiRadioEnabled ? qsTr("Disconnected") : qsTr("Wi-Fi radio: off")

  readonly property string detail1: !ready ? "" : link === "ethernet" ? qsTr("IP: %1 · IF: %2").arg(NetworkService.ethernetIpAddress || "--").arg(NetworkService.ethernetInterface || "eth") : link === "wifi" ? qsTr("IP: %1 · IF: %2").arg(NetworkService.wifiIpAddress || "--").arg(NetworkService.wifiInterface || "wlan") : qsTr("No network connection")

  readonly property string detail2: (!ready || !link || link === "disconnected") ? "" : active?.connectionName ? qsTr("Conn: %1 (%2)").arg(active.connectionName).arg(active?.type || "") : ""

  readonly property string secondary: !ready ? "" : link === "ethernet" && NetworkService.wifiOnline ? `${qsTr("WiFi")}: ${ssid || "--"} ${strength ? `(${strength}%)` : ""} · ${qsTr("IP: %1 · IF: %2").arg(NetworkService.wifiIpAddress || "--").arg(NetworkService.wifiInterface || "wlan")}` : link === "wifi" && NetworkService.ethernetOnline ? qsTr("Ethernet: IP: %1 · IF: %2").arg(NetworkService.ethernetIpAddress || "--").arg(NetworkService.ethernetInterface || "eth") : ""

  // Custom network icon with band indicator
  Item {
    id: iconButton
    implicitWidth: Theme.itemHeight
    implicitHeight: Theme.itemHeight

    readonly property string tooltipText: [root.title, root.detail1, root.detail2, root.secondary].filter(t => t).join("\n")
    readonly property bool hovered: mouseArea.containsMouse
    readonly property color bgColor: hovered ? Theme.onHoverColor : Theme.inactiveColor
    readonly property color fgColor: Theme.textContrast(bgColor)

    signal clicked(var point)

    Rectangle {
      id: bgRect
      anchors.fill: parent
      radius: Math.min(width, height) / 2
      color: mouseArea.containsPress ? Theme.onHoverColor : iconButton.bgColor
      border.color: iconButton.hovered ? Theme.onHoverColor : Theme.inactiveColor
      border.width: 1

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }
      Behavior on border.color {
        ColorAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }

      Column {
        anchors.centerIn: parent
        spacing: -2

        Text {
          text: root.netIcon
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          font.bold: true
          color: root.link === "wifi" && root.band ? NetworkService.getBandColor(root.band) : iconButton.fgColor
          horizontalAlignment: Text.AlignHCenter
          anchors.horizontalCenter: parent.horizontalCenter
          Behavior on color {
            ColorAnimation {
              duration: Theme.animationDuration
              easing.type: Easing.InOutQuad
            }
          }
        }

        Text {
          text: root.band ? (root.band === "2.4" ? "2.4G" : `${root.band}G`) : ""
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize * 0.5
          font.bold: true
          color: NetworkService.getBandColor(root.band)
          horizontalAlignment: Text.AlignHCenter
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.link === "wifi" && root.band
          Behavior on color {
            ColorAnimation {
              duration: Theme.animationDuration
              easing.type: Easing.InOutQuad
            }
          }
        }
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor

      onEntered: {
        if (iconButton.tooltipText.length)
          tooltip.isVisible = true;
      }

      onExited: {
        tooltip.isVisible = false;
      }

      onClicked: function (mouse) {
        if (mouse.button === Qt.LeftButton) {
          if (!root.ready)
            return;
          const iface = NetworkService.wifiInterface || NetworkService.firstWifiInterface?.() || "";
          if (iface && NetworkService.scanWifi)
            NetworkService.scanWifi(iface, true);
        } else if (mouse.button === Qt.RightButton) {
          networkPanel.openAtItem(iconButton, mouse.x, mouse.y);
        }

        iconButton.clicked(mouse);
      }
    }

    Tooltip {
      id: tooltip
      text: iconButton.tooltipText
      target: iconButton
    }
  }

  NetworkPanel {
    id: networkPanel
    ready: root.ready
    link: root.link
    ap: root.ap
  }
}
