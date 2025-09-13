pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: network

  property var _deviceList: []
  property string _ethernetIf: ""
  property string _ethernetIp: ""
  property bool _ethernetOnline: false
  property bool _isReady: false
  property bool _isScanning: false
  property bool _isWifiRadioEnabled: true
  property double _lastDeviceRefreshMs: 0
  property double _lastWifiScanMs: 0
  property string _linkType: "disconnected"
  property var _savedWifiConnections: []
  property var _wifiAps: []
  property string _wifiIf: ""
  property string _wifiIp: ""
  property bool _wifiOnline: false
  readonly property int defaultDeviceRefreshCooldownMs: 1000
  readonly property int defaultWifiScanCooldownMs: 10000
  readonly property var deviceList: _deviceList
  property int deviceRefreshCooldownMs: defaultDeviceRefreshCooldownMs
  readonly property string ethernetIf: _ethernetIf
  readonly property string ethernetIp: _ethernetIp
  readonly property bool ethernetOnline: _ethernetOnline
  readonly property bool isReady: _isReady
  readonly property bool isScanning: _isScanning
  readonly property bool isWifiRadioEnabled: _isWifiRadioEnabled
  readonly property string linkType: _linkType
  readonly property var lowPriorityCmd: ["nice", "-n", "19", "ionice", "-c3"]
  readonly property var savedWifiConnections: _savedWifiConnections
  readonly property var uuidRegex: new RegExp("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
  readonly property var wifiAps: _wifiAps
  readonly property string wifiIf: _wifiIf
  readonly property string wifiIp: _wifiIp
  readonly property bool wifiOnline: _wifiOnline
  property int wifiScanCooldownMs: defaultWifiScanCooldownMs

  signal connectionStateChanged
  signal wifiRadioStateChanged

  function activateConnection(connId, iface) {
    const connectionId = String(connId || "").trim();
    Logger.log("NetworkService", "activateConnection(connId=", connectionId, ")");
    if (!connectionId)
      return;
    const interfaceName = String(iface || "") || firstWifiInterface();
    startConnectCommand(["nmcli", "connection", "up", "id", connectionId, "ifname", interfaceName]);
  }
  function applySavedFlags() {
    const savedSet = new Set((_savedWifiConnections || []).map(saved => saved.ssid || saved.name).filter(Boolean));
    let activeSsid = null;
    for (let index = 0; index < (_wifiAps || []).length; index++) {
      const accessPoint = _wifiAps[index];
      if (accessPoint && accessPoint.connected && accessPoint.ssid) {
        activeSsid = accessPoint.ssid;
        break;
      }
    }
    if (!activeSsid) {
      const activeDevice = chooseActiveDevice(_deviceList || []);
      if (activeDevice && activeDevice.type === "wifi" && isConnectedState(activeDevice.state))
        activeSsid = activeDevice.connectionName || null;
    }
    _wifiAps = (_wifiAps || []).map(accessPoint => {
      const updated = Object.assign({}, accessPoint || {});
      updated.saved = savedSet.has(updated.ssid);
      if (activeSsid && !updated.connected)
        updated.connected = updated.ssid === activeSsid;
      return updated;
    }).sort((left, right) => ((right.connected ? 1 : 0) - (left.connected ? 1 : 0)) || ((right.signal || 0) - (left.signal || 0)));
  }
  function chooseActiveDevice(devices) {
    if (!devices || !devices.length)
      return null;
    let ethernetDevice = null, wifiDevice = null;
    for (let index = 0; index < devices.length; index++) {
      const device = devices[index];
      if (!isConnectedDevice(device))
        continue;
      if (!ethernetDevice && device.type === "ethernet")
        ethernetDevice = device;
      else if (!wifiDevice && device.type === "wifi")
        wifiDevice = device;
    }
    return ethernetDevice || wifiDevice || null;
  }
  function computeDerivedState(devices) {
    let wifiIf = "", ethIf = "", wifiConn = false, ethConn = false, wifiIp = "", ethIp = "";
    for (let index = 0; index < devices.length; index++) {
      const device = devices[index];
      const isOn = isConnectedDevice(device);
      if (device.type === "wifi") {
        wifiIf = device.interface || wifiIf;
        wifiConn = wifiConn || isOn;
        if (device.ip4)
          wifiIp = stripCidr(device.ip4);
      } else if (device.type === "ethernet") {
        ethIf = device.interface || ethIf;
        ethConn = ethConn || isOn;
        if (device.ip4)
          ethIp = stripCidr(device.ip4);
      }
    }
    return {
      wifiIf,
      ethIf,
      wifiConn,
      ethConn,
      wifiIp,
      ethIp,
      status: ethConn ? "ethernet" : (wifiConn ? "wifi" : "disconnected")
    };
  }
  function connectToWifi(ssid, password, iface, save, name) {
    const interfaceName = String(iface || "") || firstWifiInterface();
    const clean = (typeof ssid === "string" ? ssid : String(ssid || "")).trim();
    Logger.log("NetworkService", "connectToWifi(ssid=", clean, ", iface=", interfaceName, ", save=", !!save, ")");
    if (!clean)
      return;
    if (save && String(name || "")) {
      startConnectCommand(["nmcli", "connection", "add", "type", "wifi", "ifname", interfaceName, "con-name", String(name), "ssid", clean]);
      return;
    }
    const passwordStr = String(password || "");
    const cmd = passwordStr ? ["nmcli", "device", "wifi", "connect", clean, "password", passwordStr, "ifname", interfaceName] : ["nmcli", "device", "wifi", "connect", clean, "ifname", interfaceName];
    startConnectCommand(cmd);
  }
  function dedupeWifiNetworks(entries) {
    if (!entries || !entries.length)
      return [];
    const networksBySsid = {};
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index] || {};
      const ssid = (entry.ssid || "").trim();
      if (!ssid || ssid === "--")
        continue;
      const bandLabel = inferBandLabel(entry.freq || "");
      const signalStrength = entry.signal || (entry.bars ? signalFromBars(entry.bars) : 0) || (entry.connected ? 60 : 0);
      const existing = networksBySsid[ssid];
      if (!existing) {
        networksBySsid[ssid] = {
          ssid,
          bssid: entry.bssid || "",
          signal: signalStrength,
          security: entry.security || "",
          freq: entry.freq || "",
          band: bandLabel,
          connected: !!entry.connected,
          saved: !!entry.saved
        };
      } else {
        existing.connected = existing.connected || !!entry.connected;
        existing.saved = existing.saved || !!entry.saved;
        if (signalStrength > existing.signal) {
          existing.signal = signalStrength;
          existing.bssid = entry.bssid || existing.bssid;
          existing.freq = entry.freq || existing.freq;
          existing.band = bandLabel || existing.band;
          existing.security = entry.security || existing.security;
        }
      }
    }
    const result = [];
    for (const key in networksBySsid)
      result.push(networksBySsid[key]);
    result.sort((a, b) => (b.signal || 0) - (a.signal || 0));
    return result;
  }
  function deviceByInterface(interfaceName) {
    for (let index = 0; index < _deviceList.length; index++)
      if (_deviceList[index].interface === interfaceName)
        return _deviceList[index];
    return null;
  }
  function disconnectInterface(interfaceName) {
    const typeName = (deviceByInterface(interfaceName) || {}).type || "";
    if (typeName === "ethernet")
      OSDService.showInfo(qsTr("Ethernet turned off"));
    Logger.log("NetworkService", "Disconnecting interface:", interfaceName, "type:", typeName || "unknown");
    startConnectCommand(["nmcli", "device", "disconnect", interfaceName]);
  }
  function disconnectWifi() {
    const interfaceName = firstWifiInterface();
    if (interfaceName)
      disconnectInterface(interfaceName);
  }
  function firstWifiInterface() {
    for (let index = 0; index < _deviceList.length; index++)
      if (_deviceList[index].type === "wifi")
        return _deviceList[index].interface || "";
    return "";
  }
  function forgetWifiConnection(connectionId) {
    const idStr = String(connectionId || "");
    const cmd = isUuid(idStr) ? ["nmcli", "connection", "delete", "uuid", idStr] : ["nmcli", "connection", "delete", "id", idStr];
    pForget.command = prepareCommand(cmd, false);
    pForget.connectionId = idStr;
    Logger.log("NetworkService", "Forgetting Wi-Fi connection:", idStr);
    start(pForget);
  }
  function inferBandLabel(freqStr) {
    const mhz = parseInt(String(freqStr || ""));
    if (!mhz || mhz <= 0)
      return "";
    if (mhz >= 2400 && mhz <= 2500)
      return "2.4";
    if (mhz >= 4900 && mhz <= 5900)
      return "5";
    if (mhz >= 5925 && mhz <= 7125)
      return "6";
    return "";
  }
  function isConnectedDevice(device) {
    const hasName = !!(device && device.connectionName && String(device.connectionName).trim() && String(device.connectionName).trim() !== "--");
    return isConnectedState(device && device.state) || hasName;
  }
  function isConnectedState(state) {
    const stateStr = String(state || "");
    const match = stateStr.match(/^(\d+)/);
    if (match)
      return parseInt(match[1], 10) >= 100;
    const lower = stateStr.toLowerCase().trim();
    return !!lower && lower.indexOf("connected") !== -1 && lower.indexOf("disconnected") === -1 && lower.indexOf("connecting") === -1;
  }
  function isCooldownActive(lastAt, cooldownMs, nowMs) {
    const nowTime = nowMs !== undefined ? nowMs : Date.now();
    return nowTime - (lastAt || 0) < cooldownMs;
  }
  function isUuid(value) {
    return uuidRegex.test(String(value || ""));
  }
  function parseDeviceListMultiline(text) {
    const lines = String(text || "").split(/\n+/);
    const devices = [];
    let current = {
      interface: "",
      type: "",
      state: "",
      mac: "",
      ip4: null,
      ip6: null,
      connectionName: "",
      connectionUuid: ""
    };
    for (let index = 0; index < lines.length; index++) {
      const line = (lines[index] || "").trim();
      if (!line)
        continue;
      const colonPos = line.indexOf(":");
      if (colonPos <= 0)
        continue;
      const key = line.substring(0, colonPos).trim();
      const value = line.substring(colonPos + 1).trim();
      if (key === "GENERAL.DEVICE" || key === "DEVICE") {
        if (current.interface)
          devices.push(current);
        current = {
          interface: value,
          type: "",
          state: "",
          mac: "",
          ip4: null,
          ip6: null,
          connectionName: "",
          connectionUuid: ""
        };
      } else if (key === "GENERAL.TYPE" || key === "TYPE") {
        current.type = value;
      } else if (key === "GENERAL.STATE" || key === "STATE") {
        current.state = value;
      } else if (key === "GENERAL.CONNECTION" || key === "CONNECTION") {
        current.connectionName = value;
      } else if (key === "GENERAL.CON-UUID" || key === "CON-UUID") {
        current.connectionUuid = value;
      } else if (key === "GENERAL.HWADDR" || key === "HWADDR") {
        current.mac = value;
      } else if (key.indexOf("IP4.ADDRESS") === 0 || key === "IP4.ADDRESS") {
        current.ip4 = value;
      } else if (key.indexOf("IP6.ADDRESS") === 0 || key === "IP6.ADDRESS") {
        current.ip6 = value;
      }
    }
    if (current.interface)
      devices.push(current);
    return devices;
  }
  function parseWifiListMultiline(text) {
    const lines = String(text || "").split(/\n+/);
    const results = [];
    let accessPoint = {
      ssid: "",
      bssid: "",
      signal: 0,
      security: "",
      freq: "",
      band: "",
      connected: false
    };
    for (let index = 0; index < lines.length; index++) {
      const rawLine = lines[index];
      if (!rawLine || !rawLine.trim())
        continue;
      const colonPos = rawLine.indexOf(":");
      if (colonPos <= 0)
        continue;
      const key = rawLine.substring(0, colonPos).trim();
      const value = rawLine.substring(colonPos + 1).trim();
      if (key === "IN-USE") {
        const hasSsid = accessPoint.ssid && accessPoint.ssid.length;
        const hasBssid = accessPoint.bssid && accessPoint.bssid.length;
        if (hasSsid || hasBssid)
          results.push(accessPoint);
        accessPoint = {
          ssid: "",
          bssid: "",
          signal: 0,
          security: "",
          freq: "",
          band: "",
          connected: value === "*"
        };
      } else {
        if (key === "SSID")
          accessPoint.ssid = value;
        else if (key === "BSSID")
          accessPoint.bssid = value;
        else if (key === "SIGNAL")
          accessPoint.signal = parseInt(value) || 0;
        else if (key === "BARS")
          accessPoint.bars = value;
        else if (key === "SECURITY")
          accessPoint.security = value;
        else if (key === "FREQ")
          accessPoint.freq = value;
      }
    }
    const hasSsid = accessPoint.ssid && accessPoint.ssid.length;
    const hasBssid = accessPoint.bssid && accessPoint.bssid.length;
    if (hasSsid || hasBssid)
      results.push(accessPoint);
    for (let index = 0; index < results.length; index++) {
      if (((results[index].signal | 0) === 0) && results[index].bars)
        results[index].signal = signalFromBars(results[index].bars);
    }
    return results;
  }
  function prepareCommand(args, lowPrio) {
    const base = ["env", "LC_ALL=C"].concat(args || []);
    return lowPrio ? lowPriorityCmd.concat(base) : base;
  }
  function refreshAll() {
    refreshDeviceList(false);
    if (_wifiIf && _isWifiRadioEnabled)
      scanWifi(_wifiIf);
    start(pWifiRadio);
  }
  function refreshDeviceList(force) {
    const nowTime = Date.now();
    if (!force && isCooldownActive(_lastDeviceRefreshMs, deviceRefreshCooldownMs, nowTime))
      return;
    _lastDeviceRefreshMs = nowTime;
    if (!pDeviceShow.running)
      start(pDeviceShow);
  }
  function scanWifi(iface, force) {
    const interfaceName = (iface && iface.length) ? iface : (_wifiIf || firstWifiInterface());
    if (!interfaceName || _isScanning || !_isWifiRadioEnabled)
      return;
    const device = deviceByInterface(interfaceName);
    if (device && device.state && device.state.indexOf("unavailable") !== -1)
      return;
    if (!force && isCooldownActive(_lastWifiScanMs, wifiScanCooldownMs))
      return;
    Logger.log("NetworkService", "Starting Wi-Fi list on:", interfaceName, force ? "(forced)" : "");
    _isScanning = true;
    const rescanArg = force ? "yes" : "auto";
    pWifiList.command = prepareCommand(["nmcli", "-m", "multiline", "-f", "IN-USE,SSID,BSSID,SIGNAL,BARS,SECURITY,FREQ", "device", "wifi", "list", "ifname", interfaceName, "--rescan", rescanArg], true);
    start(pWifiList);
  }
  function setWifiRadioEnabled(enabled) {
    OSDService.showInfo(enabled ? qsTr("Wi-Fi turned on") : qsTr("Wi-Fi turned off"));
    Logger.log("NetworkService", "Setting Wi-Fi radio:", enabled ? "on" : "off");
    startConnectCommand(["nmcli", "radio", "wifi", enabled ? "on" : "off"]);
  }
  function signalFromBars(bars) {
    const barsStr = String(bars || "");
    const barCount = (barsStr.match(/[▂▄▆█]/g) || []).length;
    return Math.max(0, Math.min(100, barCount * 25));
  }

  function splitNmcliFields(line) {
    const fields = [];
    let current = "";
    let isEscaped = false;
    for (let index = 0; index < line.length; index++) {
      const ch = line[index];
      if (isEscaped) {
        current += ch;
        isEscaped = false;
      } else if (ch === "\\") {
        isEscaped = true;
      } else if (ch === ":") {
        fields.push(current);
        current = "";
      } else {
        current += ch;
      }
    }
    fields.push(current);
    return fields;
  }
  function start(processRef) {
    if (!processRef || processRef.running)
      return false;
    processRef.running = true;
    return true;
  }
  function startConnectCommand(args) {
    if (pConnect.running)
      return false;
    pConnect.command = prepareCommand(args, false);
    pConnect.running = true;
    return true;
  }
  function stripCidr(addr) {
    const addrStr = String(addr || "");
    const slashPos = addrStr.indexOf("/");
    return slashPos > 0 ? addrStr.substring(0, slashPos) : addrStr;
  }
  function toggleWifiRadio() {
    setWifiRadioEnabled(!_isWifiRadioEnabled);
  }
  function unescapeNmcli(text) {
    return String(text || "").replace(/\\:/g, ":").replace(/\\\\/g, "\\");
  }
  function updateDerivedState() {
    const previousLinkType = _linkType;
    const derived = computeDerivedState(_deviceList || []);
    _wifiIf = derived.wifiIf;
    _wifiOnline = derived.wifiConn;
    _wifiIp = derived.wifiIp;
    _ethernetIf = derived.ethIf;
    _ethernetOnline = derived.ethConn;
    _ethernetIp = derived.ethIp;
    _linkType = derived.status;
    if (previousLinkType !== _linkType)
      connectionStateChanged();
  }

  Component.onCompleted: {
    _isReady = true;
    refreshAll();
    start(pSaved);
  }
  onConnectionStateChanged: {
    Logger.log("NetworkService", "Connection state:", _linkType, "wifiIf=", _wifiIf || "-", "ethIf=", _ethernetIf || "-");
    applySavedFlags();
    if (_linkType === "wifi") {
      const interfaceName = _wifiIf || firstWifiInterface();
      if (interfaceName)
        scanWifi(interfaceName, true);
    }
  }
  onWifiRadioStateChanged: Logger.log("NetworkService", "Wi-Fi radio:", _isWifiRadioEnabled ? "enabled" : "disabled")

  Timer {
    id: tMonitorDebounce

    interval: 500
    repeat: false
    running: false

    onTriggered: {
      network.refreshDeviceList(true);
      const interfaceName = network._wifiIf || network.firstWifiInterface();
      if (interfaceName && network._isWifiRadioEnabled && !network._isScanning)
        network.scanWifi(interfaceName);
    }
  }
  Timer {
    id: tMonitorRestart

    interval: 3000
    repeat: false
    running: false

    onTriggered: {
      pMonitor.running = true;
    }
  }
  Process {
    id: pMonitor

    command: network.prepareCommand(["nmcli", "monitor"], true)

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: function () {
        if (tMonitorDebounce.running)
          tMonitorDebounce.stop();
        tMonitorDebounce.start();
      }
    }

    Component.onCompleted: network.start(pMonitor)
    onRunningChanged: {
      if (!running && !tMonitorRestart.running)
        tMonitorRestart.start();
    }
  }
  Process {
    id: pDeviceShow

    command: network.prepareCommand(["nmcli", "-m", "multiline", "-f", "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,GENERAL.CON-UUID,GENERAL.HWADDR,IP4.ADDRESS,IP6.ADDRESS", "device", "show"], true)

    stdout: StdioCollector {
      onStreamFinished: function () {
        network._deviceList = network.parseDeviceListMultiline(text);
        network.updateDerivedState();
        const activeDevice = network.chooseActiveDevice(network._deviceList);
        const summary = activeDevice ? (activeDevice.interface + "/" + activeDevice.type) : "none";
        Logger.log("NetworkService", "Devices:", (network._deviceList || []).length, "active=", summary, "link=", network._linkType);
        network.applySavedFlags();
      }
    }
  }
  Process {
    id: pWifiList

    stdout: StdioCollector {
      onStreamFinished: function () {
        network._isScanning = false;
        const parsed = network.parseWifiListMultiline(text);
        network._wifiAps = network.dedupeWifiNetworks(parsed);
        network.applySavedFlags();
        network._lastWifiScanMs = Date.now();
        network.refreshDeviceList(true);
        let activeSsid = null, activeSignal = null;
        for (let index = 0; index < (network._wifiAps || []).length; index++) {
          const accessPoint = network._wifiAps[index];
          if (accessPoint && accessPoint.connected) {
            activeSsid = accessPoint.ssid;
            activeSignal = accessPoint.signal;
            break;
          }
        }
        Logger.log("NetworkService", "Wi-Fi:", (network._wifiAps || []).length, activeSsid ? ("active=" + activeSsid + " (" + (activeSignal || 0) + "%)") : "no active");
      }
    }
  }
  Process {
    id: pWifiRadio

    command: network.prepareCommand(["nmcli", "-t", "-f", "WIFI", "general"], false)

    stdout: StdioCollector {
      onStreamFinished: function () {
        const status = (text || "").trim().toLowerCase();
        const enabled = status.indexOf("enabled") !== -1 || status === "yes" || status === "on";
        if (network._isWifiRadioEnabled !== enabled) {
          network._isWifiRadioEnabled = enabled;
          network.wifiRadioStateChanged();
        }
      }
    }
  }
  Process {
    id: pConnect

    stdout: StdioCollector {
      onStreamFinished: function () {
        network.refreshDeviceList(true);
        network.start(pSaved);
        network.start(pWifiRadio);
      }
    }
  }
  Process {
    id: pSaved

    command: network.prepareCommand(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"], false)

    stdout: StdioCollector {
      onStreamFinished: function () {
        const list = [];
        const lines = (text || "").trim().split(/\n+/);
        for (let index = 0; index < lines.length; index++) {
          const line = lines[index].trim();
          if (!line)
            continue;
          const fields = network.splitNmcliFields(line);
          if (fields.length >= 2 && fields[1] === "802-11-wireless") {
            const name = network.unescapeNmcli(fields[0]);
            list.push({
              ssid: name,
              name: name
            });
          }
        }
        network._savedWifiConnections = list;
        network.applySavedFlags();
      }
    }
  }
  Process {
    id: pForget

    property string connectionId: ""

    stdout: StdioCollector {
      onStreamFinished: function () {
        Logger.log("NetworkService", "Forgot Wi-Fi connection:", pForget.connectionId || "<unknown>");
        network.refreshAll();
        network.start(pSaved);
      }
    }
  }
}
