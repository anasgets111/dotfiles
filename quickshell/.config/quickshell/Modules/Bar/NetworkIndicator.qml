pragma ComponentBehavior: Bound
import QtQuick
import qs.Config
import qs.Components
import qs.Services.Core

Item {
  id: root

  // Sizing like other small indicators
  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)
  visible: NetworkService && NetworkService.isReady

  readonly property var activeDev: (NetworkService.deviceList) ? NetworkService.chooseActiveDevice(NetworkService.deviceList || []) : null

  readonly property string preferredLink: {
    if (!NetworkService.isReady)
      return "disconnected";
    return NetworkService.linkType || "disconnected";
  }

  // Find currently connected AP in the service’s wifiAps
  // Prefer AP list, but after resume it may be stale; fall back to active device
  readonly property var connectedAp: (NetworkService.wifiAps && NetworkService.wifiAps.length) ? (NetworkService.wifiAps.find(ap => ap && ap.connected) || null) : null

  // SSID from the connected AP list, or fall back to active device connection name
  readonly property string wifiSsid: connectedAp && connectedAp.ssid && connectedAp.ssid.length > 0 ? connectedAp.ssid : ((activeDev && activeDev.type === "wifi") ? (activeDev.connectionName || "") : "")

  // Signal strength and band from AP list
  // If AP scan hasn't populated yet (e.g., immediately after unlock), show 0
  // rather than a stale value. A forced rescan is triggered when the service
  // enters Wi‑Fi state.
  readonly property int wifiSignal: connectedAp && typeof connectedAp.signal === "number" ? connectedAp.signal : 0 // 0..100
  readonly property string wifiBand: connectedAp && connectedAp.band ? connectedAp.band : ""

  function wifiIconForSignal(signal) {
    const s = Math.max(0, Math.min(100, signal | 0));
    if (s >= 95)
      return "󰤨";     // strong
    if (s >= 80)
      return "󰤥";     // good
    if (s >= 50)
      return "󰤢";     // fair
    return "󰤟";                  // weak
  }

  // Pick an icon for the current link state
  readonly property string netIcon: {
    if (!NetworkService || !NetworkService.isReady)
      return "󰤭"; // unknown/offline
    if (preferredLink === "ethernet")
      return "󰈀"; // network-wired
    if (preferredLink === "wifi")
      return wifiIconForSignal(wifiSignal);
    // disconnected
    return NetworkService.isWifiRadioEnabled ? "󰤭" : "󰤮"; // wifi-off if radio disabled
  }

  // Tooltip content pieces
  readonly property string titleText: {
    if (!NetworkService || !NetworkService.isReady)
      return qsTr("Network: initializing…");
    if (preferredLink === "ethernet")
      return qsTr("Ethernet");
    if (preferredLink === "wifi") {
      const ssid = wifiSsid && wifiSsid.length ? wifiSsid : qsTr("Wi-Fi");
      const pct = wifiSignal > 0 ? `${wifiSignal}%` : "--";
      const band = wifiBand && wifiBand.length ? (qsTr(" • %1 GHz").arg(wifiBand)) : "";
      return `${ssid} (${pct})${band}`;
    }
    // disconnected
    return NetworkService.isWifiRadioEnabled ? qsTr("Disconnected") : qsTr("Wi-Fi radio: off");
  }

  readonly property string detailText1: {
    if (!NetworkService || !NetworkService.isReady)
      return "";
    if (preferredLink === "ethernet") {
      const ip = NetworkService.ethernetIp || "--";
      const iface = NetworkService.ethernetIf || "eth";
      return qsTr("IP: %1 · IF: %2").arg(ip).arg(iface);
    }
    if (preferredLink === "wifi") {
      const ip = NetworkService.wifiIp || "--";
      const iface = NetworkService.wifiIf || "wlan";
      return qsTr("IP: %1 · IF: %2").arg(ip).arg(iface);
    }
    return qsTr("No network connection");
  }

  readonly property string detailText2: {
    if (!NetworkService || !NetworkService.isReady)
      return "";
    const name = activeDev && activeDev.connectionName ? activeDev.connectionName : "";
    const type = activeDev && activeDev.type ? activeDev.type : "";
    // Only show when actually connected to wifi/ethernet
    const show = (root.preferredLink === "wifi" || root.preferredLink === "ethernet") && name && name.length > 0;
    return show ? qsTr("Conn: %1 (%2)").arg(name).arg(type) : "";
  }

  // Optional secondary line showing the non-preferred link when both are up
  readonly property string secondaryText: {
    if (!NetworkService || !NetworkService.isReady)
      return "";
    if (preferredLink === "ethernet" && NetworkService.wifiOnline) {
      const ssid = wifiSsid && wifiSsid.length ? wifiSsid : "";
      const pct = wifiSignal > 0 ? (wifiSignal + "%") : "";
      const ip = NetworkService.wifiIp || "--";
      const iface = NetworkService.wifiIf || "wlan";
      let head = qsTr("Wi‑Fi");
      if (ssid || pct) {
        head += ": ";
        if (ssid)
          head += ssid;
        if (pct)
          head += (ssid ? " " : "") + "(" + pct + ")";
      }
      const tail = qsTr("IP: %1 · IF: %2").arg(ip).arg(iface);
      return head.length > 0 ? (head + " · " + tail) : (qsTr("Wi‑Fi: ") + tail);
    }
    if (preferredLink === "wifi" && NetworkService.ethernetOnline) {
      const ip = NetworkService.ethernetIp || "--";
      const iface = NetworkService.ethernetIf || "eth";
      return qsTr("Ethernet: IP: %1 · IF: %2").arg(ip).arg(iface);
    }
    return "";
  }

  IconButton {
    id: iconButton
    disabled: false
    iconText: root.netIcon
    onClicked: {
      if (NetworkService && NetworkService.isReady) {
        const iface = NetworkService.wifiIf || (NetworkService.deviceList && NetworkService.firstWifiInterface ? NetworkService.firstWifiInterface() : "");
        if (iface && NetworkService.scanWifi)
          NetworkService.scanWifi(iface, true);
      }
    }
  }

  Tooltip {
    hoverSource: iconButton.area
    hAlign: Qt.AlignCenter
    target: iconButton
    contentComponent: Component {
      Column {
        spacing: 2
        // Title
        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          font.bold: true
          text: root.titleText
        }
        // Detail line 1
        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          opacity: 0.85
          text: root.detailText1
          visible: text.length > 0
        }
        // Detail line 2 (optional)
        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          opacity: 0.65
          text: root.detailText2
          visible: text.length > 0
        }
        // Secondary link (optional)
        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          opacity: 0.55
          text: root.secondaryText
          visible: text.length > 0
        }
      }
    }
  }
}
