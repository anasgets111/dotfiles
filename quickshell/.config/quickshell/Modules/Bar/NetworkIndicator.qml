pragma ComponentBehavior: Bound
import QtQuick
import qs.Config
import qs.Components
import qs.Services.Core

Item {
  id: root

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)
  visible: !!NetworkService && NetworkService.ready

  // Short helpers
  function first(arr, pred) {
    if (!arr || !arr.length)
      return null;
    for (let i = 0; i < arr.length; i++)
      if (pred(arr[i]))
        return arr[i];
    return null;
  }
  function wifiIcon(signal) {
    const s = Math.max(0, Math.min(100, signal | 0));
    return s >= 95 ? "󰤨" : s >= 80 ? "󰤥" : s >= 50 ? "󰤢" : "󰤟";
  }

  // Cached references
  readonly property bool ready: NetworkService && NetworkService.ready
  readonly property string link: ready ? (NetworkService.linkType || "disconnected") : "disconnected"
  readonly property var devs: ready ? (NetworkService.deviceList || []) : []
  readonly property var active: ready ? NetworkService.chooseActiveDevice(devs) : null
  readonly property var aps: ready ? (NetworkService.wifiAps || []) : []

  // Connected AP and derived fields
  readonly property var ap: first(aps, ap => ap && ap.connected) || null
  readonly property string ssid: ap?.ssid || ((active && active.type === "wifi") ? (active.connectionName || "") : "")
  readonly property int strength: (typeof ap?.signal === "number") ? ap.signal : 0
  readonly property string band: ap?.band || ""

  // Icon
  readonly property string netIcon: !ready ? "󰤭" : link === "ethernet" ? "󰈀" : link === "wifi" ? wifiIcon(strength) : (NetworkService.wifiRadioEnabled ? "󰤭" : "󰤮")

  // Title
  readonly property string title: !ready ? qsTr("Network: initializing…") : link === "ethernet" ? qsTr("Ethernet") : link === "wifi" ? `${(ssid || qsTr("Wi‑Fi"))} (${strength > 0 ? strength + "%" : "--"})${band ? qsTr(" • %1 GHz").arg(band) : ""}` : (NetworkService.wifiRadioEnabled ? qsTr("Disconnected") : qsTr("Wi‑Fi radio: off"))

  // Detail line 1 (IP/IF)
  readonly property string detail1: !ready ? "" : link === "ethernet" ? qsTr("IP: %1 · IF: %2").arg(NetworkService.ethernetIpAddress || "--").arg(NetworkService.ethernetInterface || "eth") : link === "wifi" ? qsTr("IP: %1 · IF: %2").arg(NetworkService.wifiIpAddress || "--").arg(NetworkService.wifiInterface || "wlan") : qsTr("No network connection")

  // Detail line 2 (Conn)
  readonly property string detail2: {
    if (!ready)
      return "";
    const name = active?.connectionName || "";
    const type = active?.type || "";
    return (link === "wifi" || link === "ethernet") && name ? qsTr("Conn: %1 (%2)").arg(name).arg(type) : "";
  }

  // Secondary line (other link)
  readonly property string secondary: {
    if (!ready)
      return "";
    if (link === "ethernet" && NetworkService.wifiOnline) {
      const ip = NetworkService.wifiIpAddress || "--";
      const iface = NetworkService.wifiInterface || "wlan";
      const head = [qsTr("Wi‑Fi"), ssid ? (": " + ssid) : "", strength ? (" (" + strength + "%)") : ""].join("");
      return `${head} · ${qsTr("IP: %1 · IF: %2").arg(ip).arg(iface)}`;
    }
    if (link === "wifi" && NetworkService.ethernetOnline) {
      return qsTr("Ethernet: IP: %1 · IF: %2").arg(NetworkService.ethernetIpAddress || "--").arg(NetworkService.ethernetInterface || "eth");
    }
    return "";
  }

  IconButton {
    id: iconButton
    iconText: root.netIcon
    onClicked: {
      if (!root.ready)
        return;
      const iface = NetworkService.wifiInterface || (NetworkService.deviceList && NetworkService.firstWifiInterface ? NetworkService.firstWifiInterface() : "");
      if (iface && NetworkService.scanWifi)
        NetworkService.scanWifi(iface, true);
    }
  }

  Tooltip {
    hoverSource: iconButton.area
    hAlign: Qt.AlignCenter
    target: iconButton
    contentComponent: Component {
      Column {
        spacing: 2

        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          font.bold: true
          text: root.title
        }
        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          opacity: 0.85
          text: root.detail1
          visible: text.length > 0
        }
        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          opacity: 0.65
          text: root.detail2
          visible: text.length > 0
        }
        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          opacity: 0.55
          text: root.secondary
          visible: text.length > 0
        }
      }
    }
  }
}
