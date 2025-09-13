pragma Singleton
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
  readonly property var savedWifiConnections: _savedWifiConnections
  readonly property var uuidRegex: new RegExp("^[0-9a-fA-F]{8}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{12}$")
  readonly property var wifiAps: _wifiAps
  readonly property string wifiIf: _wifiIf
  readonly property string wifiIp: _wifiIp
  readonly property bool wifiOnline: _wifiOnline
  property int wifiScanCooldownMs: defaultWifiScanCooldownMs

  signal connectionStateChanged
  signal wifiRadioStateChanged

  function activateConnection(connId, iface) {
    const id = String(connId || "").trim();
    Logger.log("NetworkService", "activateConnection(connId=", id, ")");
    if (!id)
      return;
    const ifname = String(iface || "") || firstWifiInterface();
    startConnectCommand(["nmcli", "connection", "up", "id", id, "ifname", ifname]);
  }
  function applySavedFlags() {
    if (!_wifiAps)
      return;
    const savedLookup = {};
    (_savedWifiConnections || []).forEach(savedItem => {
      if (savedItem.ssid)
        savedLookup[savedItem.ssid] = true;
      if (savedItem.name)
        savedLookup[savedItem.name] = true;
    });
    let activeSsid = null;
    for (let idx = 0; idx < (_wifiAps || []).length; idx++) {
      const accessPoint = _wifiAps[idx];
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
      const updatedAp = Object.assign({}, accessPoint || {});
      updatedAp.saved = !!savedLookup[updatedAp.ssid];
      if (activeSsid && !updatedAp.connected)
        updatedAp.connected = updatedAp.ssid === activeSsid;
      return updatedAp;
    }).sort((left, right) => ((right.connected ? 1 : 0) - (left.connected ? 1 : 0)) || ((right.signal || 0) - (left.signal || 0)));
  }
  function chooseActiveDevice(devices) {
    if (!devices || !devices.length)
      return null;
    let wifi = null, eth = null;
    for (let idx = 0; idx < devices.length; idx++) {
      const device = devices[idx];
      if (!isConnectedState(device.state))
        continue;
      if (!eth && device.type === "ethernet")
        eth = device;
      else if (!wifi && device.type === "wifi")
        wifi = device;
    }
    return eth || wifi || null;
  }
  function computeDerivedState(devices) {
    let wifiIfName = "", ethIfName = "", wifiConn = false, ethConn = false, wifiIp = "", ethIp = "";
    for (let idx = 0; idx < devices.length; idx++) {
      const device = devices[idx];
      const isOn = isConnectedState(device.state);
      if (device.type === "wifi") {
        wifiIfName = device.interface || wifiIfName;
        wifiConn = wifiConn || isOn;
        if (device.ip4)
          wifiIp = stripCidr(device.ip4);
      } else if (device.type === "ethernet") {
        ethIfName = device.interface || ethIfName;
        ethConn = ethConn || isOn;
        if (device.ip4)
          ethIp = stripCidr(device.ip4);
      }
    }
    return {
      wifiIf: wifiIfName,
      ethIf: ethIfName,
      wifiConn: wifiConn,
      ethConn: ethConn,
      wifiIp: wifiIp,
      ethIp: ethIp,
      status: ethConn ? "ethernet" : (wifiConn ? "wifi" : "disconnected")
    };
  }
  function connectToWifi(ssid, password, iface, save, name) {
    const ifname = String(iface || "") || firstWifiInterface();
    const cleanSsid = (typeof ssid === "string" ? ssid : String(ssid || "")).trim();
    Logger.log("NetworkService", "connectToWifi(ssid=", cleanSsid, ", iface=", ifname, ", save=", !!save, ")");
    if (!cleanSsid)
      return;
    if (save && String(name || "")) {
      startConnectCommand(["nmcli", "connection", "add", "type", "wifi", "ifname", ifname, "con-name", String(name), "ssid", cleanSsid]);
      return;
    }
    const passwordArg = String(password || "");
    const commandArgs = passwordArg ? ["nmcli", "device", "wifi", "connect", cleanSsid, "password", passwordArg, "ifname", ifname] : ["nmcli", "device", "wifi", "connect", cleanSsid, "ifname", ifname];
    startConnectCommand(commandArgs);
  }
  function dedupeWifiNetworks(entries) {
    if (!entries || !entries.length)
      return [];
    const bySsid = {};
    for (let idx = 0; idx < entries.length; idx++) {
      const entry = entries[idx] || {};
      const ssid = (entry.ssid || "").trim();
      if (!ssid || ssid === "--")
        continue;
      const band = inferBandLabel(entry.freq || "");
      const sig = entry.signal || (entry.bars ? signalFromBars(entry.bars) : 0) || (entry.connected ? 60 : 0);
      if (!bySsid[ssid]) {
        bySsid[ssid] = {
          ssid,
          bssid: entry.bssid || "",
          signal: sig,
          security: entry.security || "",
          freq: entry.freq || "",
          band,
          connected: !!entry.connected,
          saved: !!entry.saved
        };
      } else {
        const existing = bySsid[ssid];
        existing.connected = existing.connected || !!entry.connected;
        existing.saved = existing.saved || !!entry.saved;
        if (sig > existing.signal) {
          existing.signal = sig;
          existing.bssid = entry.bssid || existing.bssid;
          existing.freq = entry.freq || existing.freq;
          existing.band = band || existing.band;
          existing.security = entry.security || existing.security;
        }
      }
    }
    const result = [];
    for (var ssidKey in bySsid)
      result.push(bySsid[ssidKey]);
    result.sort((left, right) => (right.signal || 0) - (left.signal || 0));
    return result;
  }
  function deviceByInterface(iface) {
    for (let idx = 0; idx < _deviceList.length; idx++)
      if (_deviceList[idx].interface === iface)
        return _deviceList[idx];
    return null;
  }
  function disconnectInterface(iface) {
    const typeName = (deviceByInterface(iface) || {}).type || "";
    if (typeName === "ethernet")
      OSDService.showInfo(qsTr("Ethernet turned off"));
    Logger.log("NetworkService", "Disconnecting interface:", iface, "type:", typeName || "unknown");
    startConnectCommand(["nmcli", "device", "disconnect", iface]);
  }
  function disconnectWifi() {
    const ifname = firstWifiInterface();
    if (ifname)
      disconnectInterface(ifname);
  }
  function firstWifiInterface() {
    for (let idx = 0; idx < _deviceList.length; idx++)
      if (_deviceList[idx].type === "wifi")
        return _deviceList[idx].interface || "";
    return "";
  }
  function forgetWifiConnection(connectionId) {
    const id = String(connectionId || "");
    const cmd = isUuid(id) ? ["nmcli", "connection", "delete", "uuid", id] : ["nmcli", "connection", "delete", "id", id];
    pForget.command = cmd;
    pForget.connectionId = id;
    Logger.log("NetworkService", "Forgetting Wi-Fi connection:", id);
    network.startProcess(pForget);
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
  function isConnectedState(state) {
    const stateString = String(state || "");
    const match = stateString.match(/^(\d+)/);
    if (match)
      return parseInt(match[1], 10) >= 100;
    const lowerState = stateString.toLowerCase().trim();
    return !!lowerState && lowerState.indexOf("connected") !== -1 && lowerState.indexOf("disconnected") === -1 && lowerState.indexOf("connecting") === -1;
  }
  function isCooldownActive(lastAt, cooldownMs, nowMs) {
    const currentMs = nowMs !== undefined ? nowMs : Date.now();
    return currentMs - lastAt < cooldownMs;
  }
  function isUuid(v) {
    return uuidRegex.test(String(v || ""));
  }
  function parseDeviceListMultiline(text) {
    const lines = (text || "").split(/\n+/);
    const list = [];
    let currentDevice = {
      interface: "",
      type: "",
      state: "",
      mac: "",
      ip4: null,
      ip6: null,
      connectionName: "",
      connectionUuid: ""
    };
    for (let idx = 0; idx < lines.length; idx++) {
      const line = (lines[idx] || "").trim();
      if (!line)
        continue;
      const keyPos = line.indexOf(":");
      if (keyPos <= 0)
        continue;
      const key = line.substring(0, keyPos).trim();
      const value = line.substring(keyPos + 1).trim();
      if (key === "GENERAL.DEVICE" || key === "DEVICE") {
        if (currentDevice.interface)
          list.push(currentDevice);
        currentDevice = {
          interface: value,
          type: "",
          state: "",
          mac: "",
          ip4: null,
          ip6: null,
          connectionName: "",
          connectionUuid: ""
        };
      } else {
        if (key === "GENERAL.TYPE" || key === "TYPE")
          currentDevice.type = value;
        else if (key === "GENERAL.STATE" || key === "STATE")
          currentDevice.state = value;
        else if (key === "GENERAL.CONNECTION" || key === "CONNECTION")
          currentDevice.connectionName = value;
        else if (key === "GENERAL.CON-UUID" || key === "CON-UUID")
          currentDevice.connectionUuid = value;
        else if (key === "GENERAL.HWADDR" || key === "HWADDR")
          currentDevice.mac = value;
        else if (key.indexOf("IP4.ADDRESS") === 0 || key === "IP4.ADDRESS")
          currentDevice.ip4 = value;
        else if (key.indexOf("IP6.ADDRESS") === 0 || key === "IP6.ADDRESS")
          currentDevice.ip6 = value;
      }
    }
    if (currentDevice.interface)
      list.push(currentDevice);
    return list;
  }
  function parseWifiListMultiline(text) {
    const lines = (text || "").split(/\n+/);
    const accessPoints = [];
    let currentAp = null;
    for (let idx = 0; idx < lines.length; idx++) {
      const line = lines[idx];
      if (!line || !line.trim())
        continue;
      const keyPos = line.indexOf(":");
      if (keyPos <= 0)
        continue;
      const key = line.substring(0, keyPos).trim();
      const value = line.substring(keyPos + 1).trim();
      if (key === "IN-USE") {
        var hasIdentifiers = false;
        if (currentAp) {
          var candidate = currentAp || {};
          hasIdentifiers = !!((candidate.ssid && candidate.ssid.length) || (candidate.bssid && candidate.bssid.length));
        }
        if (hasIdentifiers)
          accessPoints.push(currentAp);
        currentAp = {
          ssid: "",
          bssid: "",
          signal: 0,
          security: "",
          freq: "",
          band: "",
          connected: value === "*"
        };
      } else {
        if (!currentAp)
          currentAp = {
            ssid: "",
            bssid: "",
            signal: 0,
            security: "",
            freq: "",
            band: "",
            connected: false
          };
        if (key === "SSID")
          currentAp.ssid = value;
        else if (key === "BSSID")
          currentAp.bssid = value;
        else if (key === "SIGNAL")
          currentAp.signal = parseInt(value) || 0;
        else if (key === "BARS")
          currentAp.bars = value;
        else if (key === "SECURITY")
          currentAp.security = value;
        else if (key === "FREQ")
          currentAp.freq = value;
      }
    }
    var hasTailIdentifiers = false;
    if (currentAp) {
      var tail = currentAp || {};
      hasTailIdentifiers = !!((tail.ssid && tail.ssid.length) || (tail.bssid && tail.bssid.length));
    }
    if (hasTailIdentifiers)
      accessPoints.push(currentAp);
    for (let idx = 0; idx < accessPoints.length; idx++)
      if (((accessPoints[idx].signal | 0) === 0) && accessPoints[idx].bars)
        accessPoints[idx].signal = signalFromBars(accessPoints[idx].bars);
    return accessPoints;
  }
  function refreshAll() {
    refreshDeviceList(false);
    if (_wifiIf && _isWifiRadioEnabled)
      scanWifi(_wifiIf);
    network.startProcess(pWifiRadio);
  }
  function refreshDeviceList(force) {
    const nowMs = Date.now();
    if (!force && isCooldownActive(_lastDeviceRefreshMs, deviceRefreshCooldownMs, nowMs))
      return;
    _lastDeviceRefreshMs = nowMs;
    if (!pDeviceShow.running)
      network.startProcess(pDeviceShow);
  }
  function scanWifi(iface) {
    const ifname = (iface && iface.length) ? iface : (_wifiIf || firstWifiInterface());
    if (!ifname || _isScanning || !_isWifiRadioEnabled)
      return;
    const device = deviceByInterface(ifname);
    if (device && device.state && device.state.indexOf("unavailable") !== -1)
      return;
    if (isCooldownActive(_lastWifiScanMs, wifiScanCooldownMs))
      return;
    Logger.log("NetworkService", "Starting Wi-Fi list on:", ifname);
    _isScanning = true;
    pWifiList.command = ["env", "LC_ALL=C", "nmcli", "-m", "multiline", "-f", "IN-USE,SSID,BSSID,SIGNAL,BARS,SECURITY,FREQ", "device", "wifi", "list", "ifname", ifname, "--rescan", "auto"];
    network.startProcess(pWifiList);
  }
  function setWifiRadioEnabled(enabled) {
    OSDService.showInfo(enabled ? qsTr("Wi-Fi turned on") : qsTr("Wi-Fi turned off"));
    Logger.log("NetworkService", "Setting Wi-Fi radio:", enabled ? "on" : "off");
    startConnectCommand(["nmcli", "radio", "wifi", enabled ? "on" : "off"]);
  }
  function signalFromBars(bars) {
    if (!bars)
      return 0;
    try {
      const symbolCount = (String(bars).match(/[▂▄▆█]/g) || []).length;
      return Math.max(0, Math.min(100, symbolCount * 25));
    } catch (e) {
      return 0;
    }
  }
  function startConnectCommand(commandArgs) {
    if (pConnect.running)
      return false;
    try {
      pConnect.command = commandArgs;
      pConnect.running = true;
      return true;
    } catch (e) {
      return false;
    }
  }
  function startProcess(processRef) {
    if (!processRef || processRef.running)
      return false;
    try {
      processRef.running = true;
      return true;
    } catch (e) {
      return false;
    }
  }
  function stripCidr(addr) {
    if (!addr)
      return addr;
    const addrStr = String(addr);
    const slashPos = addrStr.indexOf("/");
    return slashPos > 0 ? addrStr.substring(0, slashPos) : addrStr;
  }
  function toggleWifiRadio() {
    setWifiRadioEnabled(!_isWifiRadioEnabled);
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
  function upsertDeviceDetails(iface, details) {
    const devicesCopy = _deviceList ? _deviceList.slice() : [];
    let idx = -1;
    for (let i = 0; i < devicesCopy.length; i++)
      if (devicesCopy[i].interface === iface) {
        idx = i;
        break;
      }
    if (idx >= 0)
      devicesCopy[idx] = Object.assign({}, devicesCopy[idx], details);
    else
      devicesCopy.push(Object.assign({
        interface: iface
      }, details));
    _deviceList = devicesCopy;
  }

  Component.onCompleted: {
    _isReady = true;
    refreshAll();
    network.startProcess(pSaved);
  }
  onConnectionStateChanged: {
    Logger.log("NetworkService", "Connection state:", _linkType, "wifiIf=", _wifiIf || "-", "ethIf=", _ethernetIf || "-");
    applySavedFlags();
  }
  onWifiRadioStateChanged: Logger.log("NetworkService", "Wi-Fi radio:", _isWifiRadioEnabled ? "enabled" : "disabled")

  Timer {
    id: tMonitorDebounce

    interval: 500
    repeat: false
    running: false

    onTriggered: {
      network.refreshDeviceList(true);
      const wifiInterface = network._wifiIf || network.firstWifiInterface();
      if (wifiInterface && network._isWifiRadioEnabled && !network._isScanning)
        network.scanWifi(wifiInterface);
    }
  }
  Process {
    id: pMonitor

    command: ["nmcli", "monitor"]

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: function () {
        if (tMonitorDebounce.running)
          tMonitorDebounce.stop();
        tMonitorDebounce.start();
      }
    }

    Component.onCompleted: network.startProcess(pMonitor)
  }
  Process {
    id: pDeviceShow

    command: ["nmcli", "-m", "multiline", "-f", "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,GENERAL.CON-UUID,GENERAL.HWADDR,IP4.ADDRESS,IP6.ADDRESS", "device", "show"]

    stdout: StdioCollector {
      onStreamFinished: function () {
        network._deviceList = network.parseDeviceListMultiline(text);
        network.updateDerivedState();
        const activeDev = network.chooseActiveDevice(network._deviceList);
        const activeStr = activeDev ? (activeDev.interface + "/" + activeDev.type) : "none";
        Logger.log("NetworkService", "Devices:", (network._deviceList || []).length, "active=", activeStr, "link=", network._linkType);
        network.applySavedFlags();
      }
    }
  }
  Process {
    id: pWifiList

    stdout: StdioCollector {
      onStreamFinished: function () {
        network._isScanning = false;
        const parsedWifiList = network.parseWifiListMultiline(text);
        network._wifiAps = network.dedupeWifiNetworks(parsedWifiList);
        network.applySavedFlags();
        network._lastWifiScanMs = Date.now();
        network.refreshDeviceList(true);
        let activeSsid = null, activeSignal = null;
        for (let idx = 0; idx < (network._wifiAps || []).length; idx++) {
          const accessPoint = network._wifiAps[idx];
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

    command: ["nmcli", "-t", "-f", "WIFI", "general"]

    stdout: StdioCollector {
      onStreamFinished: function () {
        const statusText = (text || "").trim().toLowerCase();
        const enabled = statusText.indexOf("enabled") !== -1 || statusText === "yes" || statusText === "on";
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
        network.startProcess(pSaved);
        network.startProcess(pWifiRadio);
      }
    }
  }
  Process {
    id: pSaved

    command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]

    stdout: StdioCollector {
      onStreamFinished: function () {
        const list = [];
        const lines = (text || "").trim().split(/\n+/);
        for (let idx = 0; idx < lines.length; idx++) {
          const line = lines[idx].trim();
          if (!line)
            continue;
          const parts = line.split(":");
          if (parts.length >= 2 && parts[1] === "802-11-wireless") {
            const name = parts[0];
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
        network.startProcess(pSaved);
      }
    }
  }
}
