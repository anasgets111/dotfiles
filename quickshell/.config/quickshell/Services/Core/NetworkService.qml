pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: net

  property var activeDevice: null
  readonly property int defaultDeviceRefreshCooldownMs: 1000
  readonly property int defaultWifiScanCooldownMs: 10000
  property var deviceList: [] // [{ interface, type, state, ... }]
  property int deviceRefreshCooldownMs: defaultDeviceRefreshCooldownMs
  property string ethernetIf: ""
  property string ethernetIp: ""
  property bool ethernetOnline: false
  property bool isReady: false
  property bool isScanning: false
  property bool isWifiRadioEnabled: true
  property double lastDeviceRefreshMs: 0
  property double lastWifiScanMs: 0
  property string linkType: "disconnected" // "ethernet" | "wifi" | "disconnected"
  property var savedWifiConnections: [] // [{ ssid }]
  property var wifiAps: [] // last scanned, deduped by SSID
  property string wifiIf: ""
  property string wifiIp: ""
  property bool wifiOnline: false
  property int wifiScanCooldownMs: defaultWifiScanCooldownMs

  signal connectionStateChanged
  signal wifiRadioStateChanged

  function activateConnection(connId, iface) {
    const ifaceStr = String(iface || "");
    const interfaceName = ifaceStr.length > 0 ? ifaceStr : net.firstWifiInterface();
    const connectionId = String(connId || "");
    Logger.log("NetworkService", "activateConnection(connId=", connectionId, ")");
    if (!connectionId) {
      Logger.error("NetworkService", "activateConnection: missing connection identifier");
      return;
    }
    net.startConnectCommand(["nmcli", "connection", "up", "id", connectionId, "ifname", interfaceName]);
  }

  function applySavedFlags() {
    if (!net.wifiAps)
      return;

    const savedBySsid = {};
    const savedList = net.savedWifiConnections || [];
    for (let savedIndex = 0; savedIndex < savedList.length; savedIndex++)
      savedBySsid[savedList[savedIndex].ssid] = true;
    let activeSsid = null;
    for (let apIndex = 0; apIndex < net.wifiAps.length; apIndex++) {
      const accessPoint = net.wifiAps[apIndex];
      if (accessPoint && accessPoint.connected && accessPoint.ssid) {
        activeSsid = accessPoint.ssid;
        break;
      }
    }
    if (!activeSsid && net.activeDevice && net.activeDevice.type === "wifi" && net.isConnectedState(net.activeDevice.state))
      activeSsid = net.activeDevice.connectionName || null;

    const updatedList = [];
    for (let apIdx = 0; apIdx < net.wifiAps.length; apIdx++) {
      const accessPoint = net.wifiAps[apIdx] || {};
      const normalizedAp = {};
      for (var propName in accessPoint)
        normalizedAp[propName] = accessPoint[propName];
      normalizedAp.saved = !!savedBySsid[normalizedAp.ssid];
      if (activeSsid && !normalizedAp.connected)
        normalizedAp.connected = normalizedAp.ssid === activeSsid;

      updatedList.push(normalizedAp);
    }
    try {
      updatedList.sort(function (apA, apB) {
        const connectedA = apA && apA.connected ? 1 : 0;
        const connectedB = apB && apB.connected ? 1 : 0;
        if (connectedB !== connectedA)
          return connectedB - connectedA;

        const signalA = apA && apA.signal ? apA.signal : 0;
        const signalB = apB && apB.signal ? apB.signal : 0;
        return signalB - signalA;
      });
    } catch (e) {}
    net.wifiAps = updatedList;
  }

  function chooseActiveDevice(devices) {
    if (!devices || devices.length === 0)
      return null;
    // Prefer only real uplinks; ignore virtual/bridge/tunnel devices like docker0
    let wifiDevice = null, ethernetDevice = null;
    for (let idx = 0; idx < devices.length; idx++) {
      const device = devices[idx];
      if (!net.isConnectedState(device.state))
        continue;
      if (device.type === "wifi" && !wifiDevice)
        wifiDevice = device;
      else if (device.type === "ethernet" && !ethernetDevice)
        ethernetDevice = device;
    }
    // Only report ethernet/wifi as active; otherwise none
    if (ethernetDevice)
      return ethernetDevice;
    if (wifiDevice)
      return wifiDevice;
    return null;
  }

  function computeDerivedState(devices) {
    let wifiIf = "", ethIf = "";
    let wifiConn = false, ethConn = false;
    let wifiIp = "", ethIp = "";
    for (let deviceIndex = 0; deviceIndex < devices.length; deviceIndex++) {
      const device = devices[deviceIndex];
      const connected = net.isConnectedState(device.state);
      if (device.type === "wifi") {
        wifiIf = device.interface || wifiIf;
        wifiConn = wifiConn || connected;
        if (device.ip4)
          wifiIp = net.stripCidr(device.ip4);
      } else if (device.type === "ethernet") {
        ethIf = device.interface || ethIf;
        ethConn = ethConn || connected;
        if (device.ip4)
          ethIp = net.stripCidr(device.ip4);
      }
    }
    const status = ethConn ? "ethernet" : (wifiConn ? "wifi" : "disconnected");
    return {
      "wifiIf": wifiIf,
      "ethIf": ethIf,
      "wifiConn": wifiConn,
      "ethConn": ethConn,
      "wifiIp": wifiIp,
      "ethIp": ethIp,
      "status": status
    };
  }

  function connectToWifi(ssid, password, iface, save, name) {
    const ifaceStr = String(iface || "");
    const interfaceName = ifaceStr.length > 0 ? ifaceStr : net.firstWifiInterface();
    const ssidStr = (typeof ssid === "string" ? ssid : String(ssid || "")).trim();
    Logger.log("NetworkService", "connectToWifi(ssid=", ssidStr, ", iface=", interfaceName, ", save=", !!save, ")");
    if (!ssidStr) {
      Logger.error("NetworkService", "connectToWifi: invalid or empty SSID");
      return;
    }
    const nameStr = String(name || "");
    if (save && nameStr.length > 0) {
      net.startConnectCommand(["nmcli", "connection", "add", "type", "wifi", "ifname", interfaceName, "con-name", nameStr, "ssid", ssidStr]);
      return;
    }
    const pwStr = String(password || "");
    if (pwStr.length > 0)
      net.startConnectCommand(["nmcli", "device", "wifi", "connect", ssidStr, "password", pwStr, "ifname", interfaceName]);
    else
      net.startConnectCommand(["nmcli", "device", "wifi", "connect", ssidStr, "ifname", interfaceName]);
  }

  function dedupeWifiNetworks(entries) {
    if (!entries || entries.length === 0)
      return [];

    const networksBySsid = {};
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index] || {};
      const ssid = (entry.ssid || "").trim();
      if (!ssid || ssid === "--")
        continue;

      const band = net.inferBandLabel(entry.freq || "");
      if (!networksBySsid[ssid]) {
        networksBySsid[ssid] = {
          "ssid": ssid,
          "bssid": entry.bssid || "",
          "signal": entry.signal || 0,
          "security": entry.security || "",
          "freq": entry.freq || "",
          "band": band,
          "connected": !!entry.connected,
          "saved": !!entry.saved
        };
      } else {
        const existingEntry = networksBySsid[ssid];
        existingEntry.connected = existingEntry.connected || !!entry.connected;
        existingEntry.saved = existingEntry.saved || !!entry.saved;
        const newSignal = entry.signal || 0;
        if (newSignal > existingEntry.signal) {
          existingEntry.signal = newSignal;
          existingEntry.bssid = entry.bssid || existingEntry.bssid;
          existingEntry.freq = entry.freq || existingEntry.freq;
          existingEntry.band = band || existingEntry.band;
          existingEntry.security = entry.security || existingEntry.security;
        }
      }
    }
    const resultList = [];
    for (var ssidKey in networksBySsid)
      resultList.push(networksBySsid[ssidKey]);
    resultList.sort(function (networkA, networkB) {
      return (networkB.signal || 0) - (networkA.signal || 0);
    });
    return resultList;
  }

  function deviceByInterface(iface) {
    const devices = net.deviceList || [];
    for (let index = 0; index < devices.length; index++)
      if (devices[index].interface === iface) {
        return devices[index];
      }
    return null;
  }

  function disconnectInterface(iface) {
    Logger.log("NetworkService", "disconnectInterface(iface=", iface, ")");
    const device = net.deviceByInterface(iface);
    const deviceType = device ? device.type : "";
    if (deviceType === "ethernet")
      OSDService.showInfo(qsTr("Ethernet turned off"));

    net.startConnectCommand(["nmcli", "device", "disconnect", iface]);
  }

  function disconnectWifi() {
    const interfaceName = net.firstWifiInterface();
    if (interfaceName)
      net.disconnectInterface(interfaceName);
  }

  function dumpState() {
    Logger.log("NetworkService", "devices=", JSON.stringify(net.deviceList));
    Logger.log("NetworkService", "wifiAps=", JSON.stringify(net.wifiAps));
  }

  function firstWifiInterface() {
    const devices = net.deviceList || [];
    for (let index = 0; index < devices.length; index++)
      if (devices[index].type === "wifi") {
        return devices[index].interface || "";
      }
    return "";
  }

  function forgetWifiConnection(identifier) {
    const byUuid = net.isUuid(identifier);
    pForget.command = byUuid ? ["nmcli", "connection", "delete", "uuid", identifier] : ["nmcli", "connection", "delete", "id", identifier];
    net.start(pForget);
  }

  function inferBandLabel(freqStr) {
    if (!freqStr)
      return "";

    const mhzValue = parseInt(String(freqStr));
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

  function isConnectedState(state) {
    if (!state)
      return false;

    const normalized = String(state).toLowerCase().trim();
    return normalized.indexOf("connected") === 0;
  }

  function isCooldownActive(lastAt, cooldownMs, now) {
    const nowMs = now !== undefined ? now : Date.now();
    return nowMs - lastAt < cooldownMs;
  }

  function isUuid(s) {
    const patternStr = "^[0-9a-fA-F]{8}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{12}$";
    const uuidRe = new RegExp(patternStr);
    return uuidRe.test(String(s || ""));
  }

  function newWifiEntry() {
    return {
      "ssid": "",
      "bssid": "",
      "signal": 0,
      "security": "",
      "freq": "",
      "band": "",
      "connected": false
    };
  }

  function parseDeviceListMultiline(text) {
    const devices = [];
    const linesArr = (text || "").split(/\n+/);
    let currentDevice = {
      "interface": ""
    };
    for (let lineIndex = 0; lineIndex < linesArr.length; lineIndex++) {
      const line = linesArr[lineIndex].trim();
      if (!line)
        continue;

      const colonPos = line.indexOf(":");
      if (colonPos <= 0)
        continue;

      const key = line.substring(0, colonPos).trim();
      const val = line.substring(colonPos + 1).trim();
      if (key === "GENERAL.DEVICE" || key === "DEVICE") {
        if (currentDevice.interface)
          devices.push(currentDevice);

        currentDevice = {
          "interface": val,
          "type": "",
          "state": "",
          "mac": "",
          "ip4": null,
          "ip6": null,
          "connectionName": "",
          "connectionUuid": ""
        };
        continue;
      }
      if (!currentDevice)
        continue;

      if (key === "GENERAL.TYPE" || key === "TYPE")
        currentDevice.type = val;
      else if (key === "GENERAL.STATE" || key === "STATE")
        currentDevice.state = val;
      else if (key === "GENERAL.CONNECTION" || key === "CONNECTION")
        currentDevice.connectionName = val;
      else if (key === "GENERAL.CON-UUID" || key === "CON-UUID")
        currentDevice.connectionUuid = val;
      else if (key === "GENERAL.HWADDR" || key === "HWADDR")
        currentDevice.mac = val;
      else if (key.indexOf("IP4.ADDRESS") === 0 || key === "IP4.ADDRESS")
        currentDevice.ip4 = val;
      else if (key.indexOf("IP6.ADDRESS") === 0 || key === "IP6.ADDRESS")
        currentDevice.ip6 = val;
    }
    if (currentDevice.interface)
      devices.push(currentDevice);

    return devices;
  }

  function parseWifiListMultiline(text) {
    const accessPoints = [];
    function pushIfValid(entry) {
      if (!entry)
        return;

      if ((entry.ssid && entry.ssid.length > 0) || (entry.bssid && entry.bssid.length > 0))
        accessPoints.push(entry);
    }
    const linesArr = (text || "").split(/\n+/);
    let currentAp = null;
    for (let lineIndex = 0; lineIndex < linesArr.length; lineIndex++) {
      const line = linesArr[lineIndex];
      if (!line || line.trim().length === 0)
        continue;

      const colonPos = line.indexOf(":");
      if (colonPos <= 0)
        continue;

      const key = line.substring(0, colonPos).trim();
      const val = line.substring(colonPos + 1).trim();
      if (key === "IN-USE") {
        if (currentAp)
          pushIfValid(currentAp);

        currentAp = net.newWifiEntry();
        currentAp.connected = val === "*";
        continue;
      }
      if (!currentAp)
        currentAp = net.newWifiEntry();

      if (key === "SSID")
        currentAp.ssid = val;
      else if (key === "BSSID")
        currentAp.bssid = val;
      else if (key === "SIGNAL")
        currentAp.signal = parseInt(val) || 0;
      else if (key === "SECURITY")
        currentAp.security = val;
      else if (key === "FREQ")
        currentAp.freq = val;
      else if (key === "IN-USE")
        currentAp.connected = val === "*";
    }
    pushIfValid(currentAp);
    return accessPoints;
  }

  function refreshAll() {
    net.refreshDeviceList();
    const wifiIface = net.firstWifiInterface();
    if (wifiIface && net.isWifiRadioEnabled)
      net.scanWifi(wifiIface);

    net.start(pWifiRadio);
  }

  function refreshDeviceList() {
    const nowMs = Date.now();
    if (net.isCooldownActive(net.lastDeviceRefreshMs, net.deviceRefreshCooldownMs, nowMs))
      return;

    net.lastDeviceRefreshMs = nowMs;
    if (!net.start(pListDevices))
      Logger.error("NetworkService", "Unable to run device list");
  }

  function requestDeviceDetails(iface) {
    const qml = "import Quickshell.Io; Process { id: p; stdout: StdioCollector {} }";
    const proc = Qt.createQmlObject(qml, net, "dynProc_" + iface);
    if (!proc) {
      Logger.error("NetworkService", "Failed to create dynamic process");
      return;
    }
    proc.command = ["nmcli", "-m", "multiline", "-f", "ALL", "device", "show", iface];
    proc.stdout.streamFinished.connect(function () {
      const outputText = proc.stdout.text || "";
      const detailsMap = {};
      const linesArr = outputText.trim().split(/\n+/);
      for (let lineIndex = 0; lineIndex < linesArr.length; lineIndex++) {
        const line = linesArr[lineIndex];
        const colonPos = line.indexOf(":");
        if (colonPos > 0) {
          const mapKey = line.substring(0, colonPos).trim();
          const mapValue = line.substring(colonPos + 1).trim();
          detailsMap[mapKey] = mapValue;
        }
      }
      const ifname = detailsMap["GENERAL.DEVICE"] || detailsMap["DEVICE"] || iface;
      const details = {
        "mac": detailsMap["GENERAL.HWADDR"] || detailsMap["HWADDR"] || "",
        "type": detailsMap["GENERAL.TYPE"] || detailsMap["TYPE"] || "",
        "ip4": net.stripCidr(detailsMap["IP4.ADDRESS[1]"] || detailsMap["IP4.ADDRESS"] || null),
        "ip6": detailsMap["IP6.ADDRESS[1]"] || detailsMap["IP6.ADDRESS"] || null,
        "connectionName": detailsMap["GENERAL.CONNECTION"] || detailsMap["CONNECTION"] || "",
        "connectionUuid": detailsMap["GENERAL.CON-UUID"] || detailsMap["CON-UUID"] || ""
      };
      net.upsertDeviceDetails(ifname, details);
      if ((detailsMap["GENERAL.TYPE"] || detailsMap["TYPE"]) === "wifi") {
        net.wifiIf = ifname;
        net.wifiIp = net.stripCidr(details.ip4 || net.wifiIp);
      } else if ((detailsMap["GENERAL.TYPE"] || detailsMap["TYPE"]) === "ethernet") {
        net.ethernetIf = ifname;
        net.ethernetIp = net.stripCidr(details.ip4 || net.ethernetIp);
      }
      net.updateDerivedState();
      proc.destroy();
    });
    proc.running = true;
  }

  function scanWifi(iface) {
    const interfaceName = iface && iface.length ? iface : net.firstWifiInterface();
    Logger.log("NetworkService", "scanWifi(iface=", interfaceName, ")");
    if (net.isScanning)
      return;

    if (!net.isWifiRadioEnabled) {
      net.wifiAps = [];
      return;
    }
    const device = net.deviceByInterface(interfaceName);
    if (device && device.state && device.state.indexOf("unavailable") !== -1) {
      net.wifiAps = [];
      return;
    }
    if (net.isCooldownActive(net.lastWifiScanMs, net.wifiScanCooldownMs))
      return;

    net.isScanning = true;
    try {
      pWifiList.command = ["nmcli", "-m", "multiline", "-f", "IN-USE,SSID,BSSID,SIGNAL,SECURITY,FREQ", "device", "wifi", "list", "ifname", interfaceName];
      net.start(pWifiList);
    } catch (e) {
      Logger.error("NetworkService", "Unable to start wifi scan");
      net.isScanning = false;
    }
  }

  function setWifiRadioEnabled(enabled) {
    const stateArg = enabled ? "on" : "off";
    OSDService.showInfo(enabled ? qsTr("Wi-Fi turned on") : qsTr("Wi-Fi turned off"));
    net.startConnectCommand(["nmcli", "radio", "wifi", stateArg]);
  }

  function start(proc) {
    if (!proc || proc.running)
      return false;

    try {
      proc.running = true;
      return true;
    } catch (e) {
      Logger.error("NetworkService", "Failed to start process:", e);
      return false;
    }
  }

  function startConnectCommand(commandArray) {
    if (pConnect.running) {
      Logger.log("NetworkService", "pConnect busy; skip", JSON.stringify(commandArray));
      return false;
    }
    try {
      pConnect.command = commandArray;
      pConnect.running = true;
      return true;
    } catch (e) {
      Logger.error("NetworkService", "Unable to start connect cmd:", e);
      return false;
    }
  }

  function stripCidr(address) {
    if (!address)
      return address;

    const inputStr = String(address);
    const slashIdx = inputStr.indexOf("/");
    return slashIdx > 0 ? inputStr.substring(0, slashIdx) : inputStr;
  }

  function toggleWifiRadio() {
    net.setWifiRadioEnabled(!net.isWifiRadioEnabled);
  }

  function updateDerivedState() {
    const previousStatus = net.linkType;
    const derivedState = net.computeDerivedState(net.deviceList || []);
    net.wifiIf = derivedState.wifiIf;
    net.wifiOnline = derivedState.wifiConn;
    net.wifiIp = derivedState.wifiIp;
    net.ethernetIf = derivedState.ethIf;
    net.ethernetOnline = derivedState.ethConn;
    net.ethernetIp = derivedState.ethIp;
    net.linkType = derivedState.status;
    if (previousStatus !== net.linkType)
      net.connectionStateChanged();
  }

  function upsertDeviceDetails(iface, details) {
    let devices = net.deviceList ? net.deviceList.slice() : [];
    let foundIndex = -1;
    for (let index = 0; index < devices.length; index++)
      if (devices[index].interface === iface) {
        foundIndex = index;
        break;
      }
    if (foundIndex >= 0) {
      const merged = Object.assign({}, devices[foundIndex], details);
      devices[foundIndex] = merged;
    } else {
      devices = devices.concat([Object.assign({
          "interface": iface
        }, details)]);
    }
    net.deviceList = devices;
  }

  Component.onCompleted: {
    Logger.log("NetworkService", "Component.onCompleted - initializing, ready=true");
    net.isReady = true;
    net.refreshAll();
    net.start(pSaved);
  }
  onActiveDeviceChanged: {
    if (net.activeDevice) {
      const d = net.activeDevice;
      Logger.log("NetworkService", `Active device: ${d.interface} type=${d.type} state=${d.state} ip4=${d.ip4 || ""}`);
    } else {
      Logger.log("NetworkService", "Active device: none");
    }
  }
  onConnectionStateChanged: {
    Logger.log("NetworkService", "Link:", net.linkType, "wifi=", net.wifiOnline, "(", net.wifiIf, net.wifiIp, ")", "eth=", net.ethernetOnline, "(", net.ethernetIf, net.ethernetIp, ")");
  }
  onWifiRadioStateChanged: {
    Logger.log("NetworkService", "Wi-Fi radio:", net.isWifiRadioEnabled ? "enabled" : "disabled");
  }

  Timer {
    id: tMonitorDebounce

    interval: 500
    repeat: false
    running: false

    onTriggered: {
      Logger.log("NetworkService", "Monitor event: refreshing state");
      net.refreshAll();
    }
  }

  Process {
    id: pMonitor

    command: ["nmcli", "monitor"]

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: function (line) {
        if (tMonitorDebounce.running)
          tMonitorDebounce.stop();

        tMonitorDebounce.start();
      }
    }

    Component.onCompleted: {
      Logger.log("NetworkService", "Starting nmcli monitor");
      net.start(pMonitor);
    }
    onRunningChanged: function () {
      if (!running)
        Logger.log("NetworkService", "nmcli monitor stopped");
    }
  }

  Process {
    id: pWifiRadio

    command: ["nmcli", "-t", "-f", "WIFI", "general"]

    stdout: StdioCollector {
      onStreamFinished: function () {
        const stateText = (text || "").trim().toLowerCase();
        const enabled = stateText.indexOf("enabled") !== -1 || stateText === "yes" || stateText === "on";
        if (net.isWifiRadioEnabled !== enabled) {
          net.isWifiRadioEnabled = enabled;
          net.wifiRadioStateChanged();
        }
      }
    }
  }

  Process {
    id: pListDevices

    command: ["nmcli", "-m", "multiline", "-f", "DEVICE,TYPE,STATE,CONNECTION,CON-UUID", "device"]

    stderr: StdioCollector {
      onStreamFinished: function () {
        const err = (text || "").trim();
        if (err.length > 0)
          Logger.error("NetworkService", err);
      }
    }
    stdout: StdioCollector {
      onStreamFinished: function () {
        const parsed = net.parseDeviceListMultiline(text);
        net.deviceList = parsed;
        net.updateDerivedState();
        for (let deviceIdx = 0; deviceIdx < net.deviceList.length; deviceIdx++) {
          const device = net.deviceList[deviceIdx];
          if (device.type === "loopback" || device.type === "wifi-p2p")
            continue;

          net.requestDeviceDetails(device.interface);
        }
          const active = net.chooseActiveDevice(net.deviceList);
          if (active)
            net.activeDevice = active;
          else
            net.activeDevice = null;

        const total = net.deviceList ? net.deviceList.length : 0;
        const wifiCount = (net.deviceList || []).filter(d => {
          return d.type === "wifi";
        }).length;
        const ethCount = (net.deviceList || []).filter(d => {
          return d.type === "ethernet";
        }).length;
        const actIf = net.activeDevice ? net.activeDevice.interface : "none";
        Logger.log("NetworkService", `Devices: ${total} (wifi=${wifiCount}, eth=${ethCount}) active=${actIf}`);
      }
    }
  }

  Process {
    id: pWifiList

    stderr: StdioCollector {
      onStreamFinished: function () {
        const err = (text || "").trim();
        if (err.length > 0)
          Logger.error("NetworkService", err);
      }
    }
    stdout: StdioCollector {
      onStreamFinished: function () {
        net.isScanning = false;
        const parsed = net.parseWifiListMultiline(text);
        net.wifiAps = net.dedupeWifiNetworks(parsed);
        net.applySavedFlags();
        net.lastWifiScanMs = Date.now();
        const count = net.wifiAps ? net.wifiAps.length : 0;
        const top = (net.wifiAps || []).slice(0, 3).map(ap => {
          return `${ap.ssid}${ap.connected ? " (connected)" : ""}${ap.saved ? " [saved]" : ""}`;
        }).join(", ");
        Logger.log("NetworkService", `Wi-Fi scan: ${count} networks`, top ? ` | top: ${top}` : "");
      }
    }
  }

  Process {
    id: pConnect

    stderr: StdioCollector {
      onStreamFinished: function () {
        const err = (text || "").trim();
        if (err.length > 0)
          Logger.error("NetworkService", err);
      }
    }
    stdout: StdioCollector {
      onStreamFinished: function () {
        Logger.log("NetworkService", "Connected: refreshing state");
        net.refreshDeviceList();
        net.start(pSaved);
        net.start(pWifiRadio);
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
        for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
          const line = lines[lineIndex].trim();
          if (!line)
            continue;

          const parts = line.split(":");
          if (parts.length >= 2 && parts[1] === "802-11-wireless")
            list.push({
              "ssid": parts[0]
            });
        }
        net.savedWifiConnections = list;
        net.applySavedFlags();
        Logger.log("NetworkService", "Saved Wi-Fi connections:", net.savedWifiConnections.length);
      }
    }
  }

  Process {
    id: pForget

    stdout: StdioCollector {
      onStreamFinished: function () {
        Logger.log("NetworkService", "Forget finished");
        net.refreshAll();
        net.start(pSaved);
      }
    }
  }
}
