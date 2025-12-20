pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: root

  // -- Internal State --
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
  property string connectingSsid: ""
  readonly property int defaultDeviceRefreshCooldownMs: 1000
  readonly property int defaultWifiScanCooldownMs: 10000

  // -- Public API --
  readonly property alias deviceList: root._deviceList
  property int deviceRefreshCooldownMs: defaultDeviceRefreshCooldownMs
  readonly property alias ethernetInterface: root._ethernetInterface
  readonly property alias ethernetIpAddress: root._ethernetIp
  readonly property alias ethernetOnline: root._ethernetOnline
  property string linkType: "disconnected"
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
  property int wifiScanCooldownMs: defaultWifiScanCooldownMs

  signal connectionError(string ssid, string errorMessage)
  signal connectionStateChanged
  signal wifiRadioStateChanged

  // -- API Functions --
  function activateConnection(id, iface) {
    const i = (id || "").trim();
    if (!i)
      return;
    root.exec(cmdConnect, ["nmcli", "connection", "up", "uuid", i, "ifname", (iface || "").trim() || root._wifiInterface]);
  }

  function chooseActiveDevice(devices) {
    if (!devices || !devices.length)
      return null;
    const connected = devices.filter(root.isConnectedDevice);
    return connected.find(d => d.type === "ethernet") || connected.find(d => d.type === "wifi") || null;
  }

  function connectEthernet() {
    const dev = root.deviceByInterface(root._ethernetInterface);
    if (dev?.connectionUuid)
      root.exec(cmdConnect, ["nmcli", "connection", "up", "uuid", dev.connectionUuid]);
  }

  function connectToWifi(ssid, pwd, iface, save, name) {
    const s = (ssid || "").trim();
    if (!s)
      return;
    root.connectingSsid = s;
    const i = (iface || "").trim() || root._wifiInterface;
    const p = String(pwd || "");

    if (p) {
      const esc = str => str.replace(/'/g, "'\\''");
      const temp = (root._savedWifiConns || []).filter(c => c.ssid && c.ssid.startsWith("temp_" + s + "_"));
      const clean = temp.map(c => `nmcli connection delete uuid '${esc(c.connectionId)}' 2>/dev/null`).join(";");
      const cmd = `nmcli dev wifi connect '${esc(s)}' password '${esc(p)}' ifname '${esc(i)}'`;
      root.exec(cmdConnect, ["sh", "-c", clean ? clean + ";" + cmd : cmd]);
    } else {
      root.exec(cmdConnect, ["nmcli", "device", "wifi", "connect", s, "ifname", i]);
    }
  }

  function deviceByInterface(iface) {
    return root._deviceList.find(d => d.interface === iface) || null;
  }

  function disconnectEthernet() {
    root.disconnectInterface(root._ethernetInterface);
  }

  function disconnectInterface(iface) {
    if (iface)
      root.exec(cmdConnect, ["nmcli", "device", "disconnect", iface]);
  }

  function disconnectWifi() {
    root.disconnectInterface(root._wifiInterface);
  }

  function exec(proc, cmd) {
    if (proc.running)
      return;
    proc.command = cmd;
    proc.running = true;
  }

  function firstWifiInterface() {
    return root._wifiInterface;
  }

  function forgetWifiConnection(id) {
    const i = (id || "").trim();
    if (!i)
      return;
    root.exec(cmdForget, root.uuidRegex.test(i) ? ["nmcli", "connection", "delete", "uuid", i] : ["nmcli", "connection", "delete", "id", i]);
  }

  function getBandColor(band) {
    return band === "6" ? "#A6E3A1" : band === "5" ? "#89B4FA" : "#CDD6F4";
  }

  function getWifiIcon(band, signal) {
    const s = Math.max(0, Math.min(100, signal | 0));
    const icons = band === "6" ? ["", "", "", ""] : ["󰤟", "󰤢", "󰤥", "󰤨"];
    return s >= 95 ? icons[3] : s >= 80 ? icons[2] : s >= 50 ? icons[1] : icons[0];
  }

  function inferBandLabel(freqStr) {
    const f = parseInt(String(freqStr || ""), 10);
    if (f >= 2400 && f <= 2500)
      return "2.4";
    if (f >= 4900 && f <= 5900)
      return "5";
    if (f >= 5925 && f <= 7125)
      return "6";
    return "";
  }

  function isConnectedDevice(d) {
    const valid = !!(d?.connectionName?.trim() && d.connectionName.trim() !== "--");
    return root.isConnectedState(d?.state) || valid;
  }

  function isConnectedState(val) {
    const s = String(val || "").trim().toLowerCase();
    const n = parseInt(s.match(/^\d+/)?.[0] || "0", 10);
    return n >= 100 || (s.includes("connected") && !s.includes("disconnected") && !s.includes("connecting"));
  }

  function parseTerse(l) {
    const r = [];
    let b = "";
    for (let i = 0; i < l.length; i++) {
      if (l[i] === '\\' && i + 1 < l.length)
        b += l[++i];
      else if (l[i] === ':') {
        r.push(b);
        b = "";
      } else
        b += l[i];
    }
    r.push(b);
    return r;
  }

  // -- Utilities (Internal) --
  function prepareCommand(args) {
    return ["env", "LC_ALL=C"].concat(args);
  }

  function refreshAll() {
    root.refreshDeviceList(false);
    if (root._wifiRadioEnabled && root._wifiInterface)
      root.scanWifi(root._wifiInterface);
    if (!procStatus.running)
      procStatus.running = true;
    if (!procSaved.running)
      procSaved.running = true;
  }

  function refreshDeviceList(force) {
    if (!force && (Date.now() - root._lastDeviceRefreshMs < root.deviceRefreshCooldownMs))
      return;
    root._lastDeviceRefreshMs = Date.now();
    if (!procDevices.running)
      procDevices.running = true;
  }

  function scanWifi(iface, force) {
    const i = iface || root._wifiInterface;
    if (!i || root._scanning)
      return;
    if (!force && (!root._wifiRadioEnabled || Date.now() - root._lastWifiScanMs < root.wifiScanCooldownMs))
      return;
    root._scanning = true;
    root._lastScanWasForced = !!force;
    root.exec(procScan, root.lowPriorityCommand.concat(root.prepareCommand(["nmcli", "-t", "-f", "IN-USE,SSID,BSSID,SIGNAL,SECURITY,FREQ", "device", "wifi", "list", "ifname", i, "--rescan", force ? "yes" : "auto"])));
  }

  function setNetworkingEnabled(e) {
    root.exec(cmdConnect, ["nmcli", "networking", e ? "on" : "off"]);
  }

  function setWifiRadioEnabled(e) {
    root.exec(cmdConnect, ["nmcli", "radio", "wifi", e ? "on" : "off"]);
  }

  function toggleNetworking() {
    root.setNetworkingEnabled(!root._networkingEnabled);
  }

  function toggleWifiRadio() {
    root.setWifiRadioEnabled(!root._wifiRadioEnabled);
  }

  function updateWifiFlags() {
    if (!root._wifiAps.length)
      return;
    const s = new Set((root._savedWifiConns || []).map(c => c.ssid));
    root._wifiAps = root._wifiAps.map(a => {
      const cp = Object.assign({}, a);
      cp.saved = s.has(cp.ssid);
      return cp;
    });
  }

  Component.onCompleted: {
    root._ready = true;
    procMonitor.running = true;
    root.refreshAll();
    Logger.log("NetworkService", "ready");
  }

  // -- Processes --
  Process {
    id: procMonitor

    command: root.prepareCommand(["nmcli", "monitor"])

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

  Process {
    id: procStatus

    command: root.prepareCommand(["nmcli", "-t", "-f", "WIFI,STATE", "general"])

    stdout: StdioCollector {
      onStreamFinished: {
        const p = (text || "").trim().split(":");
        if (p.length < 2)
          return;
        const w = p[0] === "enabled" || p[0] === "yes";
        const n = p[1] !== "asleep" && p[1] !== "disabled";
        if (root._wifiRadioEnabled !== w) {
          root._wifiRadioEnabled = w;
          Logger.log("NetworkService", `wifi radio: ${w ? "enabled" : "disabled"}`);
          root.wifiRadioStateChanged();
        }
        if (root._networkingEnabled !== n)
          root._networkingEnabled = n;
      }
    }
  }

  Process {
    id: procDevices

    command: root.prepareCommand(["nmcli", "-t", "-f", "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,IP4.ADDRESS,IP6.ADDRESS,GENERAL.CONNECTION,GENERAL.CON-UUID,GENERAL.HWADDR", "device", "show"])

    stdout: StdioCollector {
      onStreamFinished: {
        const d = [], lines = (text || "").split("\n");
        let cur = {};
        for (let i = 0; i < lines.length; i++) {
          const f = root.parseTerse(lines[i].trim());
          if (f.length < 2)
            continue;
          const k = f[0], v = f[1];
          if (k === "GENERAL.DEVICE") {
            if (cur.interface)
              d.push(cur);
            cur = {
              interface: v,
              type: "",
              state: "",
              ip4: "",
              ip6: "",
              connectionName: "",
              connectionUuid: "",
              mac: ""
            };
          } else if (k === "GENERAL.TYPE")
            cur.type = v;
          else if (k === "GENERAL.STATE")
            cur.state = v;
          else if (k === "GENERAL.CONNECTION")
            cur.connectionName = v;
          else if (k === "GENERAL.CON-UUID")
            cur.connectionUuid = v;
          else if (k === "GENERAL.HWADDR")
            cur.mac = v;
          else if (k.includes("IP4.ADDRESS"))
            cur.ip4 = v.split("/")[0];
          else if (k.includes("IP6.ADDRESS"))
            cur.ip6 = v.split("/")[0];
        }
        if (cur.interface)
          d.push(cur);
        root._deviceList = d;

        let wIf = "", eIf = "", wIp = "", eIp = "", wOn = false, eOn = false;
        for (let i = 0; i < d.length; i++) {
          const dev = d[i];
          if (root.isConnectedDevice(dev)) {
            if (dev.type === "wifi") {
              wIf = dev.interface;
              wOn = true;
              wIp = dev.ip4;
            } else if (dev.type === "ethernet") {
              eIf = dev.interface;
              eOn = true;
              eIp = dev.ip4;
            }
          } else if (dev.type === "wifi") {
            if (!wIf)
              wIf = dev.interface; // Fallback to first wifi interface
          } else if (dev.type === "ethernet") {
            if (!eIf)
              eIf = dev.interface; // Fallback to first ethernet interface
          }
        }
        root._wifiInterface = wIf;
        root._wifiOnline = wOn;
        root._wifiIp = wIp;
        root._ethernetInterface = eIf;
        root._ethernetOnline = eOn;
        root._ethernetIp = eIp;
        const ln = eOn ? "ethernet" : (wOn ? "wifi" : "disconnected");
        if (root.linkType !== ln) {
          root.linkType = ln;
          Logger.log("NetworkService", `link: ${ln} (wifi: ${wIf || "-"}, eth: ${eIf || "-"})`);
          root.connectionStateChanged();
        }
      }
    }
  }

  Process {
    id: procScan

    stdout: StdioCollector {
      onStreamFinished: {
        root._scanning = false;
        root._lastWifiScanMs = Date.now();
        const map = {}, lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
          const f = root.parseTerse(lines[i]);
          if (f.length < 6)
            continue;
          const ssid = f[1], act = f[0] === "*", sig = parseInt(f[3]) || 0;
          if (!ssid || ssid === "--")
            continue;
          if (!map[ssid] || act || (!map[ssid].active && sig > map[ssid].signal)) {
            const band = root.inferBandLabel(f[5]);
            map[ssid] = {
              active: act,
              ssid: ssid,
              bssid: f[2],
              signal: sig,
              security: f[4],
              freq: f[5],
              band: band,
              connected: act,
              saved: false
            };
          }
        }
        const keys = Object.keys(map);
        if (root._lastScanWasForced && !keys.length && root._wifiRadioEnabled) {
          root._lastScanWasForced = false;
          retryTimer.restart();
          return;
        }
        root._lastScanWasForced = false;
        root._wifiAps = keys.map(k => map[k]).sort((a, b) => (b.active ? 1 : 0) - (a.active ? 1 : 0) || b.signal - a.signal);
        Logger.log("NetworkService", `wifi scan: ${root._wifiAps.length} networks`);
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

    command: root.prepareCommand(["nmcli", "-t", "-f", "NAME,TYPE,UUID", "connection", "show"])

    stdout: StdioCollector {
      onStreamFinished: {
        const res = [], lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
          const f = root.parseTerse(lines[i]);
          if (f.length >= 3 && f[1] === "802-11-wireless")
            res.push({
              ssid: f[0],
              name: f[0],
              connectionId: f[2]
            });
        }
        root._savedWifiConns = res;
        root.updateWifiFlags();
      }
    }
  }

  Process {
    id: cmdConnect

    stderr: StdioCollector {
      onStreamFinished: {
        const e = (text || "").trim().toLowerCase();
        if (e) {
          const msg = e.includes("secrets") || e.includes("802-1x") ? "Wrong password" : e.includes("timeout") ? "Connection timeout" : e.includes("not found") ? "Network not found" : "Connection failed";
          Logger.log("NetworkService", `connection error: ${root.connectingSsid || "unknown"} - ${msg}`);
          root.connectionError(root.connectingSsid, msg);
        }
      }
    }
    stdout: StdioCollector {
      onStreamFinished: root.refreshAll()
    }
  }

  Process {
    id: cmdForget

    stdout: StdioCollector {
      onStreamFinished: root.refreshAll()
    }
  }
}
