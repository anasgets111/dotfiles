pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Services.Utils

Singleton {
  id: root

  property var _bandMap: ({})
  property string _ethernetIp: ""
  property bool _networkingEnabled: true
  property string _wifiIp: ""
  readonly property var availableWifiAps: {
    const savedNames = new Set(root.savedWifiAps.map(n => n.ssid));
    return root.wifiAps.filter(ap => !savedNames.has(ap.ssid) && ap.signal > 0);
  }
  readonly property var connectedWifiAp: root.wifiAps.find(ap => ap.connected) || null
  readonly property string ethernetInterface: root.wiredDevice?.name ?? ""
  readonly property alias ethernetIpAddress: root._ethernetIp
  readonly property bool ethernetOnline: root.wiredNetwork?.connected ?? false
  readonly property string linkType: root.ethernetOnline ? "ethernet" : (root.wifiOnline ? "wifi" : "disconnected")
  readonly property alias networkingEnabled: root._networkingEnabled
  readonly property bool ready: Networking.backend !== NetworkBackendType.None
  readonly property var savedWifiAps: root.wifiAps.filter(ap => ap.saved && (ap.signal > 0 || ap.connected))
  readonly property var viewWifiAps: root.savedWifiAps.filter(ap => !ap.connected).concat(root.availableWifiAps.filter(ap => !ap.connected))

  // --- Wifi state (native) ---
  readonly property var wifiAps: {
    const nets = root.wifiDevice?.networks.values ?? [];
    return nets.map(n => ({
          ssid: n.name,
          signal: Math.round(n.signalStrength * 100),
          band: root._bandMap[n.name] ?? "",
          security: (n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe && n.security !== WifiSecurityType.Unknown) ? "secured" : "",
          connected: n.connected,
          saved: n.known
        })).sort((a, b) => (b.connected - a.connected) || (b.signal - a.signal));
  }
  readonly property var wifiDevice: {
    for (const d of Networking.devices.values) {
      if (d.type === DeviceType.Wifi)
        return d;
    }
    return null;
  }
  readonly property string wifiInterface: root.wifiDevice?.name ?? ""
  readonly property alias wifiIpAddress: root._wifiIp
  readonly property bool wifiOnline: root.wifiDevice?.connected ?? false
  readonly property bool wifiRadioEnabled: Networking.wifiEnabled
  readonly property var wiredDevice: {
    for (const d of Networking.devices.values) {
      if (d.type === DeviceType.Wired)
        return d;
    }
    return null;
  }
  readonly property var wiredNetwork: root.wiredDevice?.network ?? null

  function connectEthernet() {
    root.wiredNetwork?.connect();
  }

  function connectHiddenWifi(ssid: string, pwd: string) {
    const s = (ssid || "").trim();
    const iface = root.wifiInterface;
    if (!s || !iface)
      return;
    const args = ["nmcli", "device", "wifi", "connect", s, "ifname", iface, "hidden", "yes"];
    if (pwd)
      args.push("password", pwd);
    root.exec(cmdAction, args);
  }

  function connectionFailReasonText(reason): string {
    if (reason === ConnectionFailReason.NoSecrets)
      return qsTr("Wrong password");
    if (reason === ConnectionFailReason.WifiAuthTimeout)
      return qsTr("Connection timeout");
    if (reason === ConnectionFailReason.WifiNetworkLost)
      return qsTr("Network not found");
    return qsTr("Connection failed");
  }

  function disconnectEthernet() {
    root.wiredDevice?.disconnect();
  }

  function disconnectWifi() {
    root.wifiDevice?.disconnect();
  }

  function exec(proc: Process, cmd: var) {
    if (proc.running)
      return;
    proc.command = ["env", "LC_ALL=C"].concat(cmd);
    proc.running = true;
  }

  // --- Helper functions ---
  function getBandColor(band: string): string {
    return band === "6" ? "#A6E3A1" : band === "5" ? "#89B4FA" : "#CDD6F4";
  }

  function getWifiIcon(band: string, signal: int): string {
    const s = Math.max(0, Math.min(100, signal | 0));
    const icons = ["󰤟", "󰤢", "󰤥", "󰤨"];
    return s >= 95 ? icons[3] : s >= 80 ? icons[2] : s >= 50 ? icons[1] : icons[0];
  }

  function inferBandLabel(freqStr): string {
    const f = parseInt(String(freqStr || "").split(" ")[0], 10);
    if (f >= 5925 && f <= 7200)
      return "6";
    if (f >= 4900 && f < 5925)
      return "5";
    if (f >= 2400 && f <= 2500)
      return "2.4";
    return "";
  }

  function parseTerse(line: string): var {
    const res = [];
    let buf = "";
    for (let i = 0; i < line.length; i++) {
      if (line[i] === '\\' && i + 1 < line.length)
        buf += line[++i];
      else if (line[i] === ':') {
        res.push(buf);
        buf = "";
      } else
        buf += line[i];
    }
    res.push(buf);
    return res;
  }

  function refreshBandData() {
    const iface = root.wifiInterface;
    if (!iface || procBand.running)
      return;
    root.exec(procBand, ["nmcli", "-t", "-f", "SSID,FREQ", "device", "wifi", "list", "ifname", iface]);
  }

  function refreshIpData() {
    if (procIp.running)
      return;
    root.exec(procIp, ["nmcli", "-t", "-f", "GENERAL.DEVICE,IP4.ADDRESS", "device", "show"]);
  }

  function refreshNetworkingStatus() {
    if (procStatus.running)
      return;
    procStatus.running = true;
  }

  function setNetworkingEnabled(enabled: bool) {
    root.exec(cmdAction, ["nmcli", "networking", enabled ? "on" : "off"]);
  }

  function setWifiRadioEnabled(enabled: bool) {
    Networking.wifiEnabled = enabled;
  }

  function startWifiScan() {
    if (root.wifiDevice)
      root.wifiDevice.scannerEnabled = true;
    root.refreshBandData();
  }

  function stopWifiScan() {
    if (root.wifiDevice)
      root.wifiDevice.scannerEnabled = false;
  }

  Component.onCompleted: {
    procMonitor.running = true;
    root.refreshIpData();
    root.refreshNetworkingStatus();
    Logger.log("NetworkService", "ready");
  }
  onEthernetInterfaceChanged: root.refreshIpData()
  onEthernetOnlineChanged: root.refreshIpData()
  onWifiInterfaceChanged: {
    if (root.wifiInterface)
      root.refreshBandData();
    root.refreshIpData();
  }
  onWifiOnlineChanged: root.refreshIpData()

  // --- Fallback refresh trigger for nmcli-only data ---
  Process {
    id: procMonitor

    command: ["env", "LC_ALL=C", "nmcli", "monitor"]

    stdout: SplitParser {
      onRead: refreshTimer.restart()
    }

    onRunningChanged: if (!running)
      restartTimer.restart()
  }

  Timer {
    id: refreshTimer

    interval: 500

    onTriggered: {
      root.refreshIpData();
      root.refreshNetworkingStatus();
    }
  }

  Timer {
    id: restartTimer

    interval: 3000

    onTriggered: procMonitor.running = true
  }

  // --- Networking enabled (nmcli fallback) ---
  Process {
    id: procStatus

    command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "NETWORKING", "general"]

    stdout: StdioCollector {
      onStreamFinished: {
        const nEnabled = (text || "").trim() === "enabled";
        if (root._networkingEnabled !== nEnabled)
          root._networkingEnabled = nEnabled;
      }
    }
  }

  // --- IP addresses (nmcli fallback, native API does not expose them) ---
  Process {
    id: procIp

    command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "GENERAL.DEVICE,IP4.ADDRESS", "device", "show"]

    stdout: StdioCollector {
      onStreamFinished: {
        let eIp = "", wIp = "";
        let curIface = "", curIp = "";

        function commit() {
          if (!curIface)
            return;
          if (curIface === root.ethernetInterface)
            eIp = curIp;
          else if (curIface === root.wifiInterface)
            wIp = curIp;
        }

        for (const line of (text || "").split("\n")) {
          const f = root.parseTerse(line.trim());
          if (f.length < 2)
            continue;
          if (f[0] === "GENERAL.DEVICE") {
            commit();
            curIface = f[1];
            curIp = "";
          } else if (f[0].includes("IP4.ADDRESS")) {
            if (!curIp)
              curIp = f[1].split("/")[0];
          }
        }
        commit();

        root._ethernetIp = eIp;
        root._wifiIp = wIp;
      }
    }
  }

  // --- Band data: lightweight supplemental scan for frequency info ---
  Process {
    id: procBand

    stdout: StdioCollector {
      onStreamFinished: {
        const map = {};
        for (const line of (text || "").split("\n")) {
          const f = root.parseTerse(line);
          if (f.length < 2 || !f[0] || f[0] === "--")
            continue;
          const band = root.inferBandLabel(f[1]);
          if (band)
            map[f[0]] = band;
        }
        root._bandMap = map;
      }
    }
  }

  // --- Hidden wifi / networking toggle command ---
  Process {
    id: cmdAction

    stderr: StdioCollector {
      onStreamFinished: {
        const err = (text || "").trim();
        if (err)
          Logger.log("NetworkService", `Error: ${err}`);
      }
    }
    stdout: StdioCollector {
      onStreamFinished: {
        root.refreshIpData();
        root.refreshNetworkingStatus();
      }
    }
  }
}
