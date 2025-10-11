pragma ComponentBehavior: Bound
import QtQuick
import qs.Config
import qs.Components
import qs.Services.Core

Item {
  id: root

  readonly property bool ready: NetworkService.ready
  readonly property string link: ready ? (NetworkService.linkType || "disconnected") : "disconnected"
  readonly property var ap: ready ? (NetworkService.wifiAps.find(ap => ap?.connected) || null) : null
  readonly property var active: ready ? NetworkService.chooseActiveDevice(NetworkService.deviceList) : null
  readonly property string ssid: ap?.ssid || (active?.type === "wifi" ? active.connectionName || "" : "")
  readonly property int strength: ap?.signal ?? 0
  readonly property string band: ap?.band || ""
  readonly property string netIcon: !ready ? "󰤭" : link === "ethernet" ? "󰈀" : link === "wifi" ? NetworkService.getWifiIcon(band, strength) : NetworkService.wifiRadioEnabled ? "󰤭" : "󰤮"
  readonly property string tooltipText: [title, detail1, detail2, secondary].filter(t => t).join("\n")

  readonly property string title: {
    if (!ready)
      return qsTr("Network: initializing…");
    if (link === "ethernet")
      return qsTr("Ethernet");
    if (link === "wifi") {
      const sig = strength > 0 ? `${strength}%` : "--";
      const bandStr = band ? qsTr(" • %1 GHz").arg(band) : "";
      return `${ssid || qsTr("Wi-Fi")} (${sig})${bandStr}`;
    }
    return NetworkService.wifiRadioEnabled ? qsTr("Disconnected") : qsTr("Wi-Fi radio: off");
  }

  readonly property string detail1: {
    if (!ready)
      return "";
    const ip = link === "ethernet" ? NetworkService.ethernetIpAddress || "--" : link === "wifi" ? NetworkService.wifiIpAddress || "--" : "";
    const iface = link === "ethernet" ? NetworkService.ethernetInterface || "eth" : link === "wifi" ? NetworkService.wifiInterface || "wlan" : "";
    return (link === "ethernet" || link === "wifi") ? qsTr("IP: %1 · IF: %2").arg(ip).arg(iface) : qsTr("No network connection");
  }

  readonly property string detail2: ready && link !== "disconnected" && active?.connectionName ? qsTr("Conn: %1 (%2)").arg(active.connectionName).arg(active?.type || "") : ""

  readonly property string secondary: {
    if (!ready)
      return "";
    if (link === "ethernet" && NetworkService.wifiOnline) {
      const sig = strength ? `(${strength}%)` : "";
      return `${qsTr("WiFi")}: ${ssid || "--"} ${sig} · ${qsTr("IP: %1 · IF: %2").arg(NetworkService.wifiIpAddress || "--").arg(NetworkService.wifiInterface || "wlan")}`;
    }
    if (link === "wifi" && NetworkService.ethernetOnline) {
      return qsTr("Ethernet: IP: %1 · IF: %2").arg(NetworkService.ethernetIpAddress || "--").arg(NetworkService.ethernetInterface || "eth");
    }
    return "";
  }

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)
  visible: ready
  signal clicked(var point)

  IconButton {
    id: iconButton
    tooltipText: root.tooltipText
    enabled: root.ready

    onClicked: function (mouse) {
      if (mouse.button === Qt.LeftButton || mouse.button === Qt.RightButton) {
        const iface = NetworkService.wifiInterface || NetworkService.firstWifiInterface() || "";
        if (iface && NetworkService.scanWifi)
          NetworkService.scanWifi(iface, true);
        networkPanel.openAtItem(iconButton, mouse.x, mouse.y);
      }
      root.clicked(mouse);
    }

    Text {
      id: mainIcon
      anchors.centerIn: parent
      text: root.netIcon
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.bold: true
      color: root.link === "wifi" && root.band ? NetworkService.getBandColor(root.band) : (iconButton.hovered ? Theme.textContrast(iconButton.colorBgHover) : Theme.textContrast(iconButton.colorBg))

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }
    }

    Text {
      text: root.band || ""
      font.family: "Roboto Condensed"
      font.pixelSize: Theme.fontSize * 0.5
      font.bold: true
      font.letterSpacing: -1
      color: NetworkService.getBandColor(root.band)
      anchors.left: mainIcon.right
      anchors.leftMargin: -2
      anchors.bottom: mainIcon.bottom
      visible: root.link === "wifi" && root.band

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }
    }
  }

  NetworkPanel {
    id: networkPanel
  }
}
