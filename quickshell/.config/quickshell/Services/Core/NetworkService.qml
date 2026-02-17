pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: root

  property var _deviceList: []
  property string _ethernetInterface: ""
  property string _ethernetIp: ""
  property bool _ethernetOnline: false
  property real _lastDeviceRefreshMs: 0
  property bool _lastScanWasForced: false
  property real _lastWifiScanMs: 0
  property bool _networkingEnabled: true
  property bool _ready: false
  property var _savedWifiConns: []
  property bool _scanning: false
  property var _wifiAps: []
  property string _wifiInterface: ""
  property string _wifiIp: ""
  property bool _wifiOnline: false
  property bool _wifiRadioEnabled: true
  property var _connectQueue: []
  property string connectingSsid: ""
  readonly property int defaultDeviceRefreshCooldownMs: 1000
  readonly property int defaultWifiScanCooldownMs: 10000
  readonly property alias deviceList: root._deviceList
  readonly property alias ethernetInterface: root._ethernetInterface
  readonly property alias ethernetIpAddress: root._ethernetIp
  readonly property alias ethernetOnline: root._ethernetOnline
  readonly property string linkType: root._ethernetOnline ? "ethernet" : (root._wifiOnline ? "wifi" : "disconnected")
  readonly property var lowPriorityCommand: ["nice", "-n", "19", "ionice", "-c3"]
  readonly property alias networkingEnabled: root._networkingEnabled
  readonly property alias ready: root._ready
  readonly property alias savedWifiAps: root._savedWifiConns
  readonly property alias scanning: root._scanning
  readonly property var uuidRegex: /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/
  readonly property alias wifiAps: root._wifiAps
  readonly property alias wifiInterface: root._wifiInterface
  readonly property alias wifiIpAddress: root._wifiIp
  readonly property alias wifiOnline: root._wifiOnline
  readonly property alias wifiRadioEnabled: root._wifiRadioEnabled

  signal connectionError(string ssid, string errorMessage)

  // 1. Connection Management
  function activateConnection(id: string, iface: string) {
    const connId = (id || "").trim();
    if (!connId)
      return;
    const ifaceName = (iface || "").trim() || root._wifiInterface;
    root.execConnect(["nmcli", "connection", "up", "uuid", connId, "ifname", ifaceName]);
  }

  function chooseActiveDevice(devices: var): var {
    if (!devices || !devices.length)
      return null;
    const connected = devices.filter(d => {
      const validName = !!(d?.connectionName?.trim() && d.connectionName.trim() !== "--");
      const stateNum = parseInt(d?.state || "0");
      return stateNum >= 100 || validName;
    });
    return connected.find(d => d.type === "ethernet") || connected.find(d => d.type === "wifi") || null;
  }

  // 2. Hardware Control
  function connectEthernet() {
    const iface = (root._ethernetInterface || "").trim();
    if (!iface)
      return;
    const dev = root.deviceByInterface(iface);
    if (dev?.connectionUuid)
      root.execConnect(["nmcli", "connection", "up", "uuid", dev.connectionUuid]);
    else
      root.execConnect(["nmcli", "device", "connect", iface]);
  }

  function connectToWifi(ssid: string, pwd: string, iface: string, hidden: bool) {
    const s = (ssid || "").trim();
    if (!s)
      return;
    root.connectingSsid = s;
    const i = (iface || "").trim() || root._wifiInterface;
    const p = String(pwd || "");

    const args = ["nmcli", "device", "wifi", "connect", s, "ifname", i];
    if (p)
      args.push("password", p);
    if (hidden)
      args.push("hidden", "yes");
    root.execConnect(args);
  }

  function deriveDeviceState(devs: var): var {
    let wIf = "", eIf = "", wIp = "", eIp = "", wOn = false, eOn = false;
    for (const d of devs) {
      const isConnected = parseInt(d.state) >= 100;
      if (d.type === "wifi") {
        if (isConnected) {
          wOn = true;
          wIf = d.interface;
          wIp = d.ip4;
        } else if (!wIf)
          wIf = d.interface;
      } else if (d.type === "ethernet") {
        if (isConnected) {
          eOn = true;
          eIf = d.interface;
          eIp = d.ip4;
        } else if (!eIf)
          eIf = d.interface;
      }
    }
    return {
      wIf,
      eIf,
      wIp,
      eIp,
      wOn,
      eOn
    };
  }

  function deviceByInterface(iface: string): var {
    return root._deviceList.find(d => d.interface === iface) || null;
  }

  function disconnectEthernet() {
    root.disconnectInterface(root._ethernetInterface);
  }

  function disconnectInterface(iface: string) {
    if (iface)
      root.execConnect(["nmcli", "device", "disconnect", iface]);
  }

  function disconnectWifi() {
    root.disconnectInterface(root._wifiInterface);
  }

  function exec(proc: Process, cmd: var) {
    if (proc.running)
      return;
    proc.command = ["env", "LC_ALL=C"].concat(cmd);
    proc.running = true;
  }

  function execConnect(cmd: var): void {
    const full = ["env", "LC_ALL=C"].concat(cmd);
    if (cmdConnect.running) {
      root._connectQueue.push(full);
      return;
    }
    cmdConnect.command = full;
    cmdConnect.running = true;
  }

  function runNextConnectCommand(): void {
    if (cmdConnect.running || !root._connectQueue.length)
      return;
    cmdConnect.command = root._connectQueue.shift();
    cmdConnect.running = true;
  }

  function forgetWifiConnection(id: string) {
    const i = (id || "").trim();
    if (!i)
      return;
    const typeFlag = root.uuidRegex.test(i) ? "uuid" : "id";
    root.exec(cmdForget, ["nmcli", "connection", "delete", typeFlag, i]);
  }

  function getBandColor(band: string): string {
    return band === "6" ? "#A6E3A1" : band === "5" ? "#89B4FA" : "#CDD6F4";
  }

  function getWifiIcon(band: string, signal: int): string {
    const s = Math.max(0, Math.min(100, signal | 0));
    const icons = ["󰤟", "󰤢", "󰤥", "󰤨"];
    return s >= 95 ? icons[3] : s >= 80 ? icons[2] : s >= 50 ? icons[1] : icons[0];
  }

  function inferBandLabel(freqStr: var): string {
    const f = parseInt(String(freqStr || "").split(" ")[0], 10);
    if (f >= 5925 && f <= 7200)
      return "6";
    if (f >= 4900 && f < 5925)
      return "5";
    if (f >= 2400 && f <= 2500)
      return "2.4";
    return "";
  }

  function parseDeviceList(text: string): var {
    const devs = [];
    const lines = (text || "").split("\n");
    let current = {};

    for (const line of lines) {
      const f = root.parseTerse(line.trim());
      if (f.length < 2)
        continue;

      if (f[0] === "GENERAL.DEVICE") {
        if (current.interface)
          devs.push(current);
        current = {
          interface: f[1],
          type: "",
          state: "",
          ip4: "",
          connectionUuid: ""
        };
      } else if (f[0] === "GENERAL.TYPE")
        current.type = f[1];
      else if (f[0] === "GENERAL.STATE")
        current.state = f[1];
      else if (f[0] === "GENERAL.CONNECTION")
        current.connectionName = f[1];
      else if (f[0] === "GENERAL.CON-UUID")
        current.connectionUuid = f[1];
      else if (f[0].includes("IP4.ADDRESS"))
        current.ip4 = f[1].split("/")[0];
    }
    if (current.interface)
      devs.push(current);
    return devs;
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

  function parseWifiScan(text: string): var {
    const map = {};
    const lines = (text || "").split("\n");
    for (const line of lines) {
      const f = root.parseTerse(line);
      if (f.length < 6)
        continue;

      const ssid = f[1];
      if (!ssid || ssid === "--")
        continue;

      const sig = parseInt(f[3]) || 0;
      const isActive = f[0] === "*";
      const current = map[ssid];

      if (!current || (isActive && !current.active) || (isActive === current.active && sig > current.signal)) {
        map[ssid] = {
          active: isActive,
          ssid: ssid,
          bssid: f[2],
          signal: sig,
          security: f[4],
          freq: f[5],
          band: root.inferBandLabel(f[5]),
          connected: isActive,
          saved: false
        };
      }
    }
    return Object.values(map).sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
  }

  function refreshAll() {
    backgroundRefreshTimer.restart();
    root.refreshDeviceList(false);
    if (root._wifiRadioEnabled && root._wifiInterface)
      root.scanWifi(root._wifiInterface, false);
    if (!procStatus.running)
      procStatus.running = true;
    if (!procSaved.running)
      procSaved.running = true;
  }

  function refreshDeviceList(force: bool) {
    backgroundRefreshTimer.restart();
    if (!force && (Date.now() - root._lastDeviceRefreshMs < root.defaultDeviceRefreshCooldownMs))
      return;
    root._lastDeviceRefreshMs = Date.now();
    if (!procDevices.running)
      procDevices.running = true;
  }

  function scanWifi(iface: string, force: bool) {
    backgroundRefreshTimer.restart();
    const i = iface || root._wifiInterface;
    if (!i || root._scanning)
      return;
    if (!force && (!root._wifiRadioEnabled || Date.now() - root._lastWifiScanMs < defaultWifiScanCooldownMs))
      return;

    root._scanning = true;
    root._lastScanWasForced = !!force;
    const args = ["nmcli", "-t", "-f", "IN-USE,SSID,BSSID,SIGNAL,SECURITY,FREQ", "device", "wifi", "list", "ifname", i, "--rescan", force ? "yes" : "auto"];
    root.exec(procScan, root.lowPriorityCommand.concat(args));
  }

  // 3. State Toggles
  function setNetworkingEnabled(enabled: bool) {
    root.execConnect(["nmcli", "networking", enabled ? "on" : "off"]);
    if (enabled) {
      root.execConnect(["nmcli", "radio", "wifi", "on"]);
      root.connectEthernet();
    } else {
      root.disconnectWifi();
      root.disconnectEthernet();
      root.execConnect(["nmcli", "radio", "wifi", "off"]);
    }
  }

  function setWifiRadioEnabled(enabled: bool) {
    root.execConnect(["nmcli", "radio", "wifi", enabled ? "on" : "off"]);
  }

  function updateWifiFlags() {
    if (!root._wifiAps.length)
      return;
    const savedSet = new Set((root._savedWifiConns || []).map(c => c.ssid));

    // Map returns a new array, triggering binding updates
    root._wifiAps = root._wifiAps.map(ap => {
      const updated = Object.assign({}, ap);
      updated.saved = savedSet.has(ap.ssid);
      return updated;
    });
  }

  Component.onCompleted: {
    root._ready = true;
    procMonitor.running = true;
    root.refreshAll();
    Logger.log("NetworkService", "ready");
  }

  // 1. Monitor
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

    onTriggered: root.refreshAll()
  }

  Timer {
    id: restartTimer

    interval: 3000

    onTriggered: procMonitor.running = true
  }

  Timer {
    id: backgroundRefreshTimer

    interval: 30000
    repeat: false
    running: true

    onTriggered: root.refreshAll()
  }

  // 2. Status
  Process {
    id: procStatus

    command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "WIFI,STATE", "general"]

    stdout: StdioCollector {
      onStreamFinished: {
        const parts = (text || "").trim().split(":");
        if (parts.length < 2)
          return;

        const wEnabled = parts[0] === "enabled" || parts[0] === "yes";
        const nEnabled = parts[1] !== "asleep" && parts[1] !== "disabled";

        if (root._wifiRadioEnabled !== wEnabled)
          root._wifiRadioEnabled = wEnabled;
        if (root._networkingEnabled !== nEnabled)
          root._networkingEnabled = nEnabled;
      }
    }
  }

  // 3. Devices
  Process {
    id: procDevices

    command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,IP4.ADDRESS,GENERAL.CONNECTION,GENERAL.CON-UUID", "device", "show"]

    stdout: StdioCollector {
      onStreamFinished: {
        const devs = root.parseDeviceList(text || "");
        root._deviceList = devs;
        const state = root.deriveDeviceState(devs);
        root._wifiInterface = state.wIf;
        root._wifiOnline = state.wOn;
        root._wifiIp = state.wIp;
        root._ethernetInterface = state.eIf;
        root._ethernetOnline = state.eOn;
        root._ethernetIp = state.eIp;
      }
    }
  }

  // 4. Wifi Scan
  Process {
    id: procScan

    stdout: StdioCollector {
      onStreamFinished: {
        root._scanning = false;
        root._lastWifiScanMs = Date.now();

        const results = root.parseWifiScan(text || "");
        if (root._lastScanWasForced && results.length === 0 && root._wifiRadioEnabled) {
          root._lastScanWasForced = false;
          retryTimer.restart();
          return;
        }

        root._wifiAps = results.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
        root._lastScanWasForced = false;
        root.updateWifiFlags();
      }
    }
  }

  Timer {
    id: retryTimer

    interval: 2000

    onTriggered: root.scanWifi(root._wifiInterface, true)
  }

  Process {
    id: procSaved

    command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "NAME,TYPE,UUID", "connection", "show"]

    stdout: StdioCollector {
      onStreamFinished: {
        const res = [];
        const lines = (text || "").split("\n");
        for (const line of lines) {
          const f = root.parseTerse(line);
          if (f.length >= 3 && f[1] === "802-11-wireless") {
            res.push({
              ssid: f[0],
              name: f[0],
              connectionId: f[2]
            });
          }
        }
        root._savedWifiConns = res;
        root.updateWifiFlags();
      }
    }
  }

  // 6. Commands
  Process {
    id: cmdConnect

    stderr: StdioCollector {
      onStreamFinished: {
        const err = (text || "").trim().toLowerCase();
        if (err) {
          const msg = err.includes("secrets") ? "Wrong password" : err.includes("timeout") ? "Connection timeout" : "Connection failed";
          Logger.log("NetworkService", `Error: ${root.connectingSsid} - ${msg}`);
          root.connectionError(root.connectingSsid, msg);
        }
      }
    }
    stdout: StdioCollector {
      onStreamFinished: {
        root.refreshAll();
        root.runNextConnectCommand();
      }
    }
  }

  Process {
    id: cmdForget

    stdout: StdioCollector {
      onStreamFinished: root.refreshAll()
    }
  }
}
