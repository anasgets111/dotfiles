pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Services.Utils

Singleton {
  id: root

  // --- Private nmcli-only state ---
  property string _ethernetInterface: ""
  property string _ethernetIp: ""
  property bool _ethernetOnline: false
  property bool _networkingEnabled: true
  property string _wifiIp: ""
  property var _bandMap: ({})

  // --- Ethernet (nmcli) ---
  readonly property alias ethernetInterface: root._ethernetInterface
  readonly property alias ethernetIpAddress: root._ethernetIp
  readonly property alias ethernetOnline: root._ethernetOnline

  // --- Networking toggle (nmcli) ---
  readonly property alias networkingEnabled: root._networkingEnabled

  // --- Wifi state (native) ---
  readonly property var wifiDevice: {
    for (const d of Networking.devices.values) {
      if (d.type === DeviceType.Wifi)
        return d;
    }
    return null;
  }
  readonly property bool wifiOnline: root.wifiDevice?.connected ?? false
  readonly property string wifiInterface: root.wifiDevice?.name ?? ""
  readonly property bool wifiRadioEnabled: Networking.wifiEnabled
  readonly property bool ready: Networking.backend !== NetworkBackendType.None
  readonly property string linkType: root._ethernetOnline ? "ethernet" : (root.wifiOnline ? "wifi" : "disconnected")

  // --- Wifi IP (nmcli, native doesn't expose it) ---
  readonly property alias wifiIpAddress: root._wifiIp

  // --- Wifi APs: native data + band from supplemental scan ---
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

  // --- Scanner control ---
  function startWifiScan() {
    if (root.wifiDevice)
      root.wifiDevice.scannerEnabled = true;
    root.refreshBandData();
  }

  function stopWifiScan() {
    if (root.wifiDevice)
      root.wifiDevice.scannerEnabled = false;
  }

  function refreshBandData() {
    const iface = root.wifiInterface;
    if (!iface || procBand.running)
      return;
    root.exec(procBand, ["nmcli", "-t", "-f", "SSID,FREQ", "device", "wifi", "list", "ifname", iface]);
  }

  // --- Wifi radio toggle ---
  function setWifiRadioEnabled(enabled: bool) {
    Networking.wifiEnabled = enabled;
  }

  // --- Wifi disconnect (delegates to native) ---
  function disconnectWifi() {
    root.wifiDevice?.disconnect();
  }

  // --- Hidden wifi (nmcli only, no native support for hidden flag) ---
  function connectHiddenWifi(ssid: string, pwd: string, iface: string) {
    const s = (ssid || "").trim();
    if (!s)
      return;
    const i = (iface || "").trim();
    const args = ["nmcli", "device", "wifi", "connect", s, "ifname", i, "hidden", "yes"];
    if (pwd)
      args.push("password", pwd);
    root.exec(cmdConnect, args);
  }

  // --- Ethernet actions (nmcli only, no ethernet in native DeviceType) ---
  function connectEthernet() {
    const iface = (root._ethernetInterface || "").trim();
    if (!iface)
      return;
    root.exec(cmdConnect, ["nmcli", "device", "connect", iface]);
  }

  function disconnectEthernet() {
    if (root._ethernetInterface)
      root.exec(cmdConnect, ["nmcli", "device", "disconnect", root._ethernetInterface]);
  }

  // --- Networking toggle (nmcli only) ---
  function setNetworkingEnabled(enabled: bool) {
    root.exec(cmdConnect, ["nmcli", "networking", enabled ? "on" : "off"]);
  }

  // --- Connection error helper (for consumers without Quickshell.Networking import) ---
  function connectionFailReasonText(reason): string {
    if (reason === ConnectionFailReason.NoSecrets)
      return qsTr("Wrong password");
    if (reason === ConnectionFailReason.WifiAuthTimeout)
      return qsTr("Connection timeout");
    if (reason === ConnectionFailReason.WifiNetworkLost)
      return qsTr("Network not found");
    return qsTr("Connection failed");
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

  function exec(proc: Process, cmd: var) {
    if (proc.running)
      return;
    proc.command = ["env", "LC_ALL=C"].concat(cmd);
    proc.running = true;
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

  // Refresh band data when wifi interface becomes available
  onWifiInterfaceChanged: if (root.wifiInterface)
    root.refreshBandData()

  Component.onCompleted: {
    procMonitor.running = true;
    procDevices.running = true;
    procStatus.running = true;
    Logger.log("NetworkService", "ready");
  }

  // --- nmcli monitor (ethernet / networking state changes) ---
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
      if (!procDevices.running)
        procDevices.running = true;
      if (!procStatus.running)
        procStatus.running = true;
    }
  }

  Timer {
    id: restartTimer

    interval: 3000

    onTriggered: procMonitor.running = true
  }

  // --- Networking enabled (nmcli) ---
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

  // --- Ethernet state + wifi IP (nmcli) ---
  Process {
    id: procDevices

    command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,IP4.ADDRESS", "device", "show"]

    stdout: StdioCollector {
      onStreamFinished: {
        let eIf = "", eIp = "", eOn = false, wIp = "";
        let curIface = "", curType = "", curState = "", curIp = "";

        function commit() {
          const connected = parseInt(curState) >= 100;
          if (curType === "ethernet") {
            if (connected) {
              eOn = true;
              eIf = curIface;
              eIp = curIp;
            } else if (!eIf) {
              eIf = curIface;
            }
          } else if (curType === "wifi" && connected && !wIp) {
            wIp = curIp;
          }
        }

        for (const line of (text || "").split("\n")) {
          const f = root.parseTerse(line.trim());
          if (f.length < 2)
            continue;
          if (f[0] === "GENERAL.DEVICE") {
            commit();
            curIface = f[1];
            curType = "";
            curState = "";
            curIp = "";
          } else if (f[0] === "GENERAL.TYPE") {
            curType = f[1];
          } else if (f[0] === "GENERAL.STATE") {
            curState = f[1];
          } else if (f[0].includes("IP4.ADDRESS")) {
            curIp = f[1].split("/")[0];
          }
        }
        commit();

        root._ethernetInterface = eIf;
        root._ethernetOnline = eOn;
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

  // --- Ethernet / hidden wifi command ---
  Process {
    id: cmdConnect

    stderr: StdioCollector {
      onStreamFinished: {
        const err = (text || "").trim();
        if (err)
          Logger.log("NetworkService", `Error: ${err}`);
      }
    }
    stdout: StdioCollector {
      onStreamFinished: {
        if (!procDevices.running)
          procDevices.running = true;
        if (!procStatus.running)
          procStatus.running = true;
      }
    }
  }
}
