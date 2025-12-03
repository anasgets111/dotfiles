pragma ComponentBehavior: Bound
import QtQuick
import qs.Config
import qs.Components
import qs.Services.Core

Item {
  id: root

  readonly property var active: ready ? NetworkService.chooseActiveDevice(NetworkService.deviceList) : null
  readonly property var ap: ready ? (NetworkService.wifiAps.find(ap => ap?.connected) || null) : null
  readonly property string band: (ap && ap.band) ? String(ap.band) : ""
  readonly property string detail1: {
    if (!ready)
      return "";
    const ip = link === "ethernet" ? (NetworkService.ethernetIpAddress || "--") : link === "wifi" ? (NetworkService.wifiIpAddress || "--") : "";
    const iface = link === "ethernet" ? (NetworkService.ethernetInterface || "eth") : link === "wifi" ? (NetworkService.wifiInterface || "wlan") : "";
    return (link === "ethernet" || link === "wifi") ? qsTr("IP: %1 · IF: %2").arg(ip).arg(iface) : qsTr("No network connection");
  }
  readonly property string detail2: (ready && link !== "disconnected" && active && active.connectionName) ? qsTr("Conn: %1 (%2)").arg(active.connectionName).arg(active.type || "") : ""
  readonly property string link: ready ? (NetworkService.linkType || "disconnected") : "disconnected"
  readonly property string netIcon: (!ready) ? "󰤭" : (link === "ethernet" ? "󰈀" : (link === "wifi" ? (NetworkService.getWifiIcon ? NetworkService.getWifiIcon(band, strength) : "") : (NetworkService.wifiRadioEnabled ? "󰤭" : "󰤮")))
  readonly property bool ready: NetworkService.ready
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
  readonly property string ssid: (ap && ap.ssid) ? String(ap.ssid) : ((active && active.type === "wifi") ? (active.connectionName || "") : "")
  readonly property int strength: (ap && typeof ap.signal === "number") ? ap.signal : (active && typeof active.signal === "number" ? active.signal : 0)
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
  readonly property string tooltipText: [title, detail1, detail2, secondary].filter(t => t).join("\n")

  signal clicked(var point)

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)
  visible: ready

  IconButton {
    id: iconButton

    enabled: root.ready
    tooltipText: root.tooltipText

    onClicked: function (mouse) {
      if (mouse.button === Qt.LeftButton || mouse.button === Qt.RightButton) {
        const iface = NetworkService.wifiInterface || NetworkService.firstWifiInterface() || "";
        if (iface && NetworkService.scanWifi)
          NetworkService.scanWifi(iface, true);
        networkPanelLoader.active = true;
      }
      root.clicked(mouse);
    }

    Text {
      id: mainIcon

      anchors.centerIn: parent
      color: root.link === "wifi" && root.band ? NetworkService.getBandColor(root.band) : (iconButton.hovered ? Theme.textContrast(iconButton.colorBgHover) : Theme.textContrast(iconButton.colorBg))
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      text: root.netIcon

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }
    }

    Text {
      anchors.bottom: mainIcon.bottom
      anchors.left: mainIcon.right
      anchors.leftMargin: -Theme.spacingXs / 2
      color: NetworkService.getBandColor(root.band)
      font.bold: true
      font.family: "Roboto Condensed"
      font.letterSpacing: -1
      font.pixelSize: Theme.fontXs
      text: root.band || ""
      visible: root.link === "wifi" && root.band

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }
    }
  }

  // Component definition for NetworkPanel (better isolation)
  Component {
    id: networkPanelComponent

    NetworkPanel {
      property var loaderRef

      onPanelClosed: loaderRef.active = false
    }
  }

  // Loader for lazy-loading the panel
  Loader {
    id: networkPanelLoader

    active: false
    sourceComponent: networkPanelComponent

    onLoaded: {
      const panel = item as NetworkPanel;
      panel.loaderRef = networkPanelLoader;
      panel.openAtItem(iconButton, 0, 0);
    }
  }
}
