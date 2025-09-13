pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: networkService

  property var activeDevice: null
  readonly property int defaultDeviceRefreshCooldownMs: 1000
  readonly property int defaultWifiScanCooldownMs: 10000
  property var deviceList: []
  property int deviceRefreshCooldownMs: defaultDeviceRefreshCooldownMs
  property string ethernetIf: ""
  property string ethernetIp: ""
  property bool ethernetOnline: false
  property bool isReady: false
  property bool isScanning: false
  property bool isWifiRadioEnabled: true
  property double lastDeviceRefreshMs: 0
  property double lastWifiScanMs: 0
  property string linkType: "disconnected"
  property var savedWifiConnections: []
  property var wifiAps: []
  property string wifiIf: ""
  property string wifiIp: ""
  property bool wifiOnline: false
  property int wifiScanCooldownMs: defaultWifiScanCooldownMs
  property string lastWifiScanIf: ""
  property bool wifiRescanRetryPending: false

  signal connectionStateChanged
  signal wifiRadioStateChanged

  function activateConnection(connId, iface) {
    const connectionId = String(connId || "").trim();
    Logger.log("NetworkService", "activateConnection(connId=", connectionId, ")");

    if (!connectionId)
      return;
    const ifname = String(iface || "") || networkService.firstWifiInterface();
    networkService.startConnectCommand(["nmcli", "connection", "up", "id", connectionId, "ifname", ifname]);
  }

  function applySavedFlags() {
    if (!networkService.wifiAps)
      return;
    const saved = {};
    (networkService.savedWifiConnections || []).forEach(savedConnection => saved[savedConnection.ssid] = true);
    let active = null;
    for (let index = 0; index < (networkService.wifiAps || []).length; index++) {
      const accessPoint = networkService.wifiAps[index];
      if (accessPoint && accessPoint.connected && accessPoint.ssid) {
        active = accessPoint.ssid;
        break;
      }
    }
    if (!active && networkService.activeDevice && networkService.activeDevice.type === "wifi" && networkService.isConnectedState(networkService.activeDevice.state))
      active = networkService.activeDevice.connectionName || null;
    networkService.wifiAps = (networkService.wifiAps || []).map(accessPoint => {
      const updatedAp = Object.assign({}, accessPoint || {});
      updatedAp.saved = !!saved[updatedAp.ssid];
      if (active && !updatedAp.connected)
        updatedAp.connected = updatedAp.ssid === active;
      return updatedAp;
    }).sort((left, right) => ((right.connected ? 1 : 0) - (left.connected ? 1 : 0)) || ((right.signal || 0) - (left.signal || 0)));
  }

  function chooseActiveDevice(devices) {
    if (!devices || !devices.length)
      return null;
    let wifi = null, ethernet = null;
    for (let index = 0; index < devices.length; index++) {
      const device = devices[index];
      if (!networkService.isConnectedState(device.state))
        continue;
      if (!ethernet && device.type === "ethernet")
        ethernet = device;
      else if (!wifi && device.type === "wifi")
        wifi = device;
    }
    return ethernet || wifi || null;
  }

  function computeDerivedState(devices) {
    let wifiIf = "", ethIf = "", wifiConn = false, ethConn = false, wifiIp = "", ethIp = "";
    for (let index = 0; index < devices.length; index++) {
      const device = devices[index], isConnected = networkService.isConnectedState(device.state);
      if (device.type === "wifi") {
        wifiIf = device.interface || wifiIf;
        wifiConn = wifiConn || isConnected;
        if (device.ip4)
          wifiIp = networkService.stripCidr(device.ip4);
      } else if (device.type === "ethernet") {
        ethIf = device.interface || ethIf;
        ethConn = ethConn || isConnected;
        if (device.ip4)
          ethIp = networkService.stripCidr(device.ip4);
      }
    }
    return {
      wifiIf: wifiIf,
      ethIf: ethIf,
      wifiConn: wifiConn,
      ethConn: ethConn,
      wifiIp: wifiIp,
      ethIp: ethIp,
      status: ethConn ? "ethernet" : (wifiConn ? "wifi" : "disconnected")
    };
  }

  function connectToWifi(ssid, password, iface, save, name) {
    const interfaceName = String(iface || "") || networkService.firstWifiInterface();
    const ssidTrimmed = (typeof ssid === "string" ? ssid : String(ssid || "")).trim();
    Logger.log("NetworkService", "connectToWifi(ssid=", ssidTrimmed, ", iface=", interfaceName, ", save=", !!save, ")");

    if (!ssidTrimmed)
      return;
    const connectionName = String(name || "");
    if (save && connectionName) {
      networkService.startConnectCommand(["nmcli", "connection", "add", "type", "wifi", "ifname", interfaceName, "con-name", connectionName, "ssid", ssidTrimmed]);
      return;
    }
    const passwordString = String(password || "");
    networkService.startConnectCommand(passwordString ? ["nmcli", "device", "wifi", "connect", ssidTrimmed, "password", passwordString, "ifname", interfaceName] : ["nmcli", "device", "wifi", "connect", ssidTrimmed, "ifname", interfaceName]);
  }

  function dedupeWifiNetworks(entries) {
    if (!entries || !entries.length)
      return [];
    const networksBySsid = {};
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index] || {}, ssid = (entry.ssid || "").trim();
      if (!ssid || ssid === "--")
        continue;
      const band = networkService.inferBandLabel(entry.freq || ""), signalValue = entry.signal || (entry.bars ? networkService.signalFromBars(entry.bars) : 0) || (entry.connected ? 60 : 0);
      if (!networksBySsid[ssid])
        networksBySsid[ssid] = {
          ssid: ssid,
          bssid: entry.bssid || "",
          signal: signalValue,
          security: entry.security || "",
          freq: entry.freq || "",
          band: band,
          connected: !!entry.connected,
          saved: !!entry.saved
        };
      else {
        const existing = networksBySsid[ssid];
        existing.connected = existing.connected || !!entry.connected;
        existing.saved = existing.saved || !!entry.saved;
        if (signalValue > existing.signal) {
          existing.signal = signalValue;
          existing.bssid = entry.bssid || existing.bssid;
          existing.freq = entry.freq || existing.freq;
          existing.band = band || existing.band;
          existing.security = entry.security || existing.security;
        }
      }
    }
    const result = [];
    for (var ssidKey in networksBySsid)
      result.push(networksBySsid[ssidKey]);
    result.sort((left, right) => (right.signal || 0) - (left.signal || 0));
    return result;
  }

  function deviceByInterface(iface) {
    const list = networkService.deviceList || [];
    for (let index = 0; index < list.length; index++)
      if (list[index].interface === iface)
        return list[index];
    return null;
  }

  function disconnectInterface(iface) {
    const deviceType = (networkService.deviceByInterface(iface) || {}).type || "";
    if (deviceType === "ethernet")
      OSDService.showInfo(qsTr("Ethernet turned off"));
    networkService.startConnectCommand(["nmcli", "device", "disconnect", iface]);
  }

  function disconnectWifi() {
    const ifname = networkService.firstWifiInterface();
    if (ifname)
      networkService.disconnectInterface(ifname);
  }

  function firstWifiInterface() {
    const list = networkService.deviceList || [];
    for (let index = 0; index < list.length; index++)
      if (list[index].type === "wifi")
        return list[index].interface || "";
    return "";
  }

  function forgetWifiConnection(connectionId) {
    pForget.command = networkService.isUuid(connectionId) ? ["nmcli", "connection", "delete", "uuid", connectionId] : ["nmcli", "connection", "delete", "id", connectionId];
    networkService.start(pForget);
  }

  function inferBandLabel(freqStr) {
    const mhzValue = parseInt(String(freqStr || ""));
    if (!mhzValue || mhzValue <= 0)
      return "";
    if (mhzValue >= 2400 && mhzValue <= 2500)
      return "2.4";
    if (mhzValue >= 4900 && mhzValue <= 5900)
      return "5";
    if (mhzValue >= 5925 && mhzValue <= 7125)
      return "6";
    return "";
  }

  function signalFromBars(bars) {
    if (!bars)
      return 0;
    try {
      const count = (String(bars).match(/[▂▄▆█]/g) || []).length;
      return Math.max(0, Math.min(100, count * 25));
    } catch (err) {
      return 0;
    }
  }

  function isConnectedState(state) {
    const stateText = String(state || "").toLowerCase().trim();
    return !!stateText && stateText.indexOf("connected") !== -1 && stateText.indexOf("disconnected") === -1 && stateText.indexOf("connecting") === -1;
  }

  function isCooldownActive(lastAt, cooldownMs, currentTimeMs) {
    const nowMs = currentTimeMs !== undefined ? currentTimeMs : Date.now();
    return nowMs - lastAt < cooldownMs;
  }
  function isUuid(value) {
    const uuidRegex = new RegExp("^[0-9a-fA-F]{8}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{12}$");
    return uuidRegex.test(String(value || ""));
  }

  function parseDeviceListMultiline(text) {
    const lines = (text || "").split(/\n+/), list = [];
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
      const colonIndex = line.indexOf(":"), key = line.substring(0, colonIndex).trim(), val = line.substring(colonIndex + 1).trim();
      if (colonIndex <= 0)
        continue;
      if (key === "GENERAL.DEVICE" || key === "DEVICE") {
        if (current.interface)
          list.push(current);
        current = {
          interface: val,
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
          current.type = val;
        else if (key === "GENERAL.STATE" || key === "STATE")
          current.state = val;
        else if (key === "GENERAL.CONNECTION" || key === "CONNECTION")
          current.connectionName = val;
        else if (key === "GENERAL.CON-UUID" || key === "CON-UUID")
          current.connectionUuid = val;
        else if (key === "GENERAL.HWADDR" || key === "HWADDR")
          current.mac = val;
        else if (key.indexOf("IP4.ADDRESS") === 0 || key === "IP4.ADDRESS")
          current.ip4 = val;
        else if (key.indexOf("IP6.ADDRESS") === 0 || key === "IP6.ADDRESS")
          current.ip6 = val;
      }
    }
    if (current.interface)
      list.push(current);
    return list;
  }

  function parseWifiListMultiline(text) {
    const lines = (text || "").split(/\n+/), result = [];
    let accessPoint = null;
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index];
      if (!line || !line.trim())
        continue;
      const colonIndex = line.indexOf(":"), key = line.substring(0, colonIndex).trim(), val = line.substring(colonIndex + 1).trim();
      if (colonIndex <= 0)
        continue;
      if (key === "IN-USE") {
        if (accessPoint) {
          const apObj = accessPoint || {};
          if ((apObj.ssid && apObj.ssid.length) || (apObj.bssid && apObj.bssid.length))
            result.push(accessPoint);
        }
        accessPoint = {
          ssid: "",
          bssid: "",
          signal: 0,
          security: "",
          freq: "",
          band: "",
          connected: val === "*"
        };
      } else {
        if (!accessPoint)
          accessPoint = {
            ssid: "",
            bssid: "",
            signal: 0,
            security: "",
            freq: "",
            band: "",
            connected: false
          };
        if (key === "SSID")
          accessPoint.ssid = val;
        else if (key === "BSSID")
          accessPoint.bssid = val;
        else if (key === "SIGNAL")
          accessPoint.signal = parseInt(val) || 0;
        else if (key === "BARS")
          accessPoint.bars = val;
        else if (key === "SECURITY")
          accessPoint.security = val;
        else if (key === "FREQ")
          accessPoint.freq = val;
      }
    }
    if (accessPoint) {
      const apObj = accessPoint || {};
      if ((apObj.ssid && apObj.ssid.length) || (apObj.bssid && apObj.bssid.length))
        result.push(accessPoint);
    }
    for (let index = 0; index < result.length; index++)
      if (((result[index].signal | 0) === 0) && result[index].bars)
        result[index].signal = networkService.signalFromBars(result[index].bars);
    return result;
  }

  function refreshAll() {
    networkService.refreshDeviceList(false);
    const wifiIface = networkService.firstWifiInterface();
    if (wifiIface && networkService.isWifiRadioEnabled)
      networkService.scanWifi(wifiIface);
    networkService.start(pWifiRadio);
  }

  function refreshDeviceList(force) {
    const nowMs = Date.now();
    if (!force && networkService.isCooldownActive(networkService.lastDeviceRefreshMs, networkService.deviceRefreshCooldownMs, nowMs))
      return;
    networkService.lastDeviceRefreshMs = nowMs;
    if (pListDevices.running)
      return;
    networkService.start(pListDevices);
  }

  function requestDeviceDetails(iface) {
    const qmlSource = "import Quickshell.Io; Process { id: detailProcess; stdout: StdioCollector {} }";
    const proc = Qt.createQmlObject(qmlSource, networkService, "dynProc_" + iface);
    if (!proc)
      return;
    proc.command = ["nmcli", "-m", "multiline", "-f", "ALL", "device", "show", iface];
    proc.stdout.streamFinished.connect(function () {
      const fieldMap = {}, linesArray = (proc.stdout.text || "").trim().split(/\n+/);
      for (let index = 0; index < linesArray.length; index++) {
        const line = linesArray[index], colonIndex = line.indexOf(":");
        if (colonIndex > 0)
          fieldMap[line.substring(0, colonIndex).trim()] = line.substring(colonIndex + 1).trim();
      }
      const interfaceName = fieldMap["GENERAL.DEVICE"] || fieldMap["DEVICE"] || iface, details = {
        mac: fieldMap["GENERAL.HWADDR"] || fieldMap["HWADDR"] || "",
        type: fieldMap["GENERAL.TYPE"] || fieldMap["TYPE"] || "",
        ip4: networkService.stripCidr(fieldMap["IP4.ADDRESS[1]"] || fieldMap["IP4.ADDRESS"] || null),
        ip6: fieldMap["IP6.ADDRESS[1]"] || fieldMap["IP6.ADDRESS"] || null,
        connectionName: fieldMap["GENERAL.CONNECTION"] || fieldMap["CONNECTION"] || "",
        connectionUuid: fieldMap["GENERAL.CON-UUID"] || fieldMap["CON-UUID"] || ""
      };
      networkService.upsertDeviceDetails(interfaceName, details);
      const deviceType = fieldMap["GENERAL.TYPE"] || fieldMap["TYPE"];
      if (deviceType === "wifi") {
        networkService.wifiIf = interfaceName;
        networkService.wifiIp = networkService.stripCidr(details.ip4 || networkService.wifiIp);
      } else if (deviceType === "ethernet") {
        networkService.ethernetIf = interfaceName;
        networkService.ethernetIp = networkService.stripCidr(details.ip4 || networkService.ethernetIp);
      }
      networkService.updateDerivedState();
      proc.destroy();
    });
    proc.running = true;
  }

  function scanWifi(iface) {
    const interfaceName = (iface && iface.length) ? iface : networkService.firstWifiInterface();
    if (networkService.isScanning)
      return;
    if (!networkService.isWifiRadioEnabled)
      return;
    const device = networkService.deviceByInterface(interfaceName);
    if (device && device.state && device.state.indexOf("unavailable") !== -1)
      return;
    if (networkService.isCooldownActive(networkService.lastWifiScanMs, networkService.wifiScanCooldownMs))
      return;
    networkService.isScanning = true;
    try {
      networkService.lastWifiScanIf = interfaceName;
      pWifiRescan.hadError = false;
      pWifiRescan.command = ["nmcli", "device", "wifi", "rescan", "ifname", interfaceName];
      pWifiList.command = ["nmcli", "-m", "multiline", "-f", "IN-USE,SSID,BSSID,SIGNAL,BARS,SECURITY,FREQ", "device", "wifi", "list", "ifname", interfaceName];
      networkService.start(pWifiRescan);
    } catch (err) {
      networkService.isScanning = false;
    }
  }

  function setWifiRadioEnabled(enabled) {
    OSDService.showInfo(enabled ? qsTr("Wi-Fi turned on") : qsTr("Wi-Fi turned off"));
    networkService.startConnectCommand(["nmcli", "radio", "wifi", enabled ? "on" : "off"]);
  }

  function start(proc) {
    if (!proc || proc.running)
      return false;
    try {
      proc.running = true;
      return true;
    } catch (err) {
      return false;
    }
  }
  function startConnectCommand(commandArray) {
    if (pConnect.running)
      return false;
    try {
      pConnect.command = commandArray;
      pConnect.running = true;
      return true;
    } catch (err) {
      return false;
    }
  }
  function stripCidr(addr) {
    if (!addr)
      return addr;
    const text = String(addr), slashIndex = text.indexOf("/");
    return slashIndex > 0 ? text.substring(0, slashIndex) : text;
  }
  function toggleWifiRadio() {
    networkService.setWifiRadioEnabled(!networkService.isWifiRadioEnabled);
  }

  function updateDerivedState() {
    const previousLinkType = networkService.linkType, derived = networkService.computeDerivedState(networkService.deviceList || []);
    networkService.wifiIf = derived.wifiIf;
    networkService.wifiOnline = derived.wifiConn;
    networkService.wifiIp = derived.wifiIp;
    networkService.ethernetIf = derived.ethIf;
    networkService.ethernetOnline = derived.ethConn;
    networkService.ethernetIp = derived.ethIp;
    networkService.linkType = derived.status;
    if (previousLinkType !== networkService.linkType)
      networkService.connectionStateChanged();
    if (networkService.linkType === "wifi" && networkService.wifiIf && networkService.isWifiRadioEnabled && !networkService.isScanning)
      networkService.scanWifi(networkService.wifiIf);
  }

  function upsertDeviceDetails(iface, details) {
    const devicesArray = (networkService.deviceList ? networkService.deviceList.slice() : []);
    let foundIndex = -1;
    for (let index = 0; index < devicesArray.length; index++)
      if (devicesArray[index].interface === iface) {
        foundIndex = index;
        break;
      }
    if (foundIndex >= 0)
      devicesArray[foundIndex] = Object.assign({}, devicesArray[foundIndex], details);
    else
      devicesArray.push(Object.assign({
        interface: iface
      }, details));
    networkService.deviceList = devicesArray;
  }

  Component.onCompleted: {
    networkService.isReady = true;
    networkService.refreshAll();
    networkService.start(pSaved);
  }
  onActiveDeviceChanged: networkService.applySavedFlags()
  onConnectionStateChanged: networkService.applySavedFlags()

  Timer {
    id: tMonitorDebounce
    interval: 500
    repeat: false
    running: false
    onTriggered: {
      networkService.refreshDeviceList(true);
      const wifiInterface = networkService.firstWifiInterface();
      if (wifiInterface && networkService.isWifiRadioEnabled && !networkService.isScanning)
        networkService.scanWifi(wifiInterface);
      networkService.start(pWifiRadio);
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
    Component.onCompleted: {
      networkService.start(pMonitor);
    }
  }

  Process {
    id: pWifiRadio
    command: ["nmcli", "-t", "-f", "WIFI", "general"]
    stdout: StdioCollector {
      onStreamFinished: function () {
        const textNormalized = (text || "").trim().toLowerCase();
        const enabled = textNormalized.indexOf("enabled") !== -1 || textNormalized === "yes" || textNormalized === "on";
        if (networkService.isWifiRadioEnabled !== enabled) {
          networkService.isWifiRadioEnabled = enabled;
          networkService.wifiRadioStateChanged();
        }
      }
    }
  }

  Process {
    id: pListDevices
    command: ["nmcli", "-m", "multiline", "-f", "DEVICE,TYPE,STATE,CONNECTION,CON-UUID", "device"]
    stdout: StdioCollector {
      onStreamFinished: function () {
        networkService.deviceList = networkService.parseDeviceListMultiline(text);
        networkService.updateDerivedState();
        for (let index = 0; index < networkService.deviceList.length; index++) {
          const device = networkService.deviceList[index];
          if (device.type === "loopback" || device.type === "wifi-p2p")
            continue;
          networkService.requestDeviceDetails(device.interface);
        }
        networkService.activeDevice = networkService.chooseActiveDevice(networkService.deviceList) || null;
      }
    }
  }

  Process {
    id: pWifiList
    stdout: StdioCollector {
      onStreamFinished: function () {
        networkService.isScanning = false;
        const parsed = networkService.parseWifiListMultiline(text);
        networkService.wifiAps = networkService.dedupeWifiNetworks(parsed);
        networkService.applySavedFlags();
        if ((networkService.wifiAps || []).length > 0)
          networkService.lastWifiScanMs = Date.now();
        networkService.refreshDeviceList(true);
      }
    }
  }

  Process {
    id: pWifiRescan
    command: ["nmcli", "device", "wifi", "rescan"]
    property bool hadError: false
    onRunningChanged: function () {
      if (!running) {
        if (!pWifiRescan.hadError)
          networkService.start(pWifiList);
        else {
          networkService.isScanning = false;
          if (!networkService.wifiRescanRetryPending && networkService.lastWifiScanIf) {
            networkService.wifiRescanRetryPending = true;
            tWifiScanRetry.start();
          }
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: function () {
        pWifiRescan.hadError = ((text || "").trim().length > 0);
      }
    }
  }

  Timer {
    id: tWifiScanRetry
    interval: 400
    repeat: false
    running: false
    onTriggered: {
      networkService.wifiRescanRetryPending = false;
      if (!networkService.isScanning && networkService.isWifiRadioEnabled && networkService.lastWifiScanIf)
        networkService.scanWifi(networkService.lastWifiScanIf);
    }
  }

  Process {
    id: pConnect
    stdout: StdioCollector {
      onStreamFinished: function () {
        networkService.refreshDeviceList();
        networkService.start(pSaved);
        networkService.start(pWifiRadio);
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
        for (let index = 0; index < lines.length; index++) {
          const line = lines[index].trim();
          if (!line)
            continue;
          const parts = line.split(":");
          if (parts.length >= 2 && parts[1] === "802-11-wireless")
            list.push({
              ssid: parts[0]
            });
        }
        networkService.savedWifiConnections = list;
        networkService.applySavedFlags();
      }
    }
  }

  Process {
    id: pForget
    stdout: StdioCollector {
      onStreamFinished: function () {
        networkService.refreshAll();
        networkService.start(pSaved);
      }
    }
  }
}
