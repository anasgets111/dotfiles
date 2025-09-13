pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Components
import qs.Services.Core

Item {
  id: root

  // Convenience alias
  readonly property var net: NetworkService

  // Sizing like other small indicators
  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)
  visible: net && net.isReady

  // Derivations for icon + tooltip
  // Prefer Ethernet if both are connected
  readonly property string preferredLink: {
    if (!net || !net.isReady)
      return "disconnected";
    if (net.ethernetOnline)
      return "ethernet";
    if (net.wifiOnline)
      return "wifi";
    return "disconnected";
  }
  readonly property var connectedAp: (net && net.wifiAps) ? (net.wifiAps.find(ap => ap && ap.connected) || null) : null
  readonly property string wifiSsid: connectedAp && connectedAp.ssid && connectedAp.ssid.length > 0 ? connectedAp.ssid : (net && net.activeDevice && net.activeDevice.type === "wifi" ? (net.activeDevice.connectionName || "") : "")
  readonly property int wifiSignal: connectedAp && typeof connectedAp.signal === "number" ? connectedAp.signal : 0 // 0..100
  readonly property string wifiBand: connectedAp && connectedAp.band ? connectedAp.band : ""

  function wifiIconForSignal(signal) {
    const s = Math.max(0, Math.min(100, signal | 0));
    if (s >= 75)
      return "󰤨";     // strong
    if (s >= 50)
      return "󰤥";     // good
    if (s >= 25)
      return "󰤢";     // fair
    return "󰤟";                  // weak
  }

  // Pick an icon for the current link state
  readonly property string netIcon: {
    if (!net || !net.isReady)
      return "󰤭"; // unknown/offline
    if (preferredLink === "ethernet")
      return "󰈀"; // network-wired
    if (preferredLink === "wifi")
      return wifiIconForSignal(wifiSignal);
    // disconnected
    return net.isWifiRadioEnabled ? "󰤭" : "󰤮"; // wifi-off if radio disabled
  }

  // Tooltip content pieces
  readonly property string titleText: {
    if (!net || !net.isReady)
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
    return net.isWifiRadioEnabled ? qsTr("Disconnected") : qsTr("Wi-Fi radio: off");
  }
  readonly property string detailText1: {
    if (!net || !net.isReady)
      return "";
    if (preferredLink === "ethernet") {
      const ip = net.ethernetIp || "--";
      const iface = net.ethernetIf || "eth";
      return qsTr("IP: %1 · IF: %2").arg(ip).arg(iface);
    }
    if (preferredLink === "wifi") {
      const ip = net.wifiIp || "--";
      const iface = net.wifiIf || "wlan";
      return qsTr("IP: %1 · IF: %2").arg(ip).arg(iface);
    }
    return qsTr("No network connection");
  }
  readonly property string detailText2: {
    if (!net || !net.isReady)
      return "";
    const dev = net.activeDevice || null;
    const name = dev && dev.connectionName ? dev.connectionName : "";
    const type = dev && dev.type ? dev.type : "";
    // Only show when actually connected to wifi/ethernet
    const show = (root.preferredLink === "wifi" || root.preferredLink === "ethernet") && name && name.length > 0;
    return show ? qsTr("Conn: %1 (%2)").arg(name).arg(type) : "";
  }
  // Optional secondary line showing the non-preferred link when both are up
  readonly property string secondaryText: {
    if (!net || !net.isReady)
      return "";
    if (preferredLink === "ethernet" && net.wifiOnline) {
      const ssid = wifiSsid && wifiSsid.length ? wifiSsid : "";
      const pct = wifiSignal > 0 ? (wifiSignal + "%") : "";
      const ip = net.wifiIp || "--";
      const iface = net.wifiIf || "wlan";
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
    if (preferredLink === "wifi" && net.ethernetOnline) {
      const ip = net.ethernetIp || "--";
      const iface = net.ethernetIf || "eth";
      return qsTr("Ethernet: IP: %1 · IF: %2").arg(ip).arg(iface);
    }
    return "";
  }

  IconButton {
    id: iconButton

    disabled: true
    iconText: root.netIcon
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
