pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: network

  // Internal state (mutable)
  property var internalDeviceList: []
  property string internalEthernetInterface: ""
  property string internalEthernetIpAddress: ""
  property bool internalEthernetOnline: false
  property bool internalReady: false
  property bool internalScanning: false
  property bool internalWifiRadioEnabled: true
  property real lastDeviceRefreshTimeMs: 0
  property real lastWifiScanTimeMs: 0
  property string linkType: "disconnected"
  property var internalSavedWifiConnections: []
  property var internalWifiAccessPoints: []
  property string internalWifiInterface: ""
  property string internalWifiIpAddress: ""
  property bool internalWifiOnline: false

  // Exposed API (readonly views or configs)
  readonly property int defaultDeviceRefreshCooldownMs: 1000
  readonly property int defaultWifiScanCooldownMs: 10000
  readonly property var deviceList: internalDeviceList
  property int deviceRefreshCooldownMs: defaultDeviceRefreshCooldownMs
  readonly property string ethernetInterface: internalEthernetInterface
  readonly property string ethernetIpAddress: internalEthernetIpAddress
  readonly property bool ethernetOnline: internalEthernetOnline
  readonly property bool ready: internalReady
  readonly property bool scanning: internalScanning
  readonly property bool wifiRadioEnabled: internalWifiRadioEnabled
  readonly property var lowPriorityCommand: ["nice", "-n", "19", "ionice", "-c3"]
  readonly property var uuidRegex: new RegExp("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
  readonly property var wifiAps: internalWifiAccessPoints
  readonly property var savedWifiAps: internalSavedWifiConnections
  readonly property string wifiInterface: internalWifiInterface
  readonly property string wifiIpAddress: internalWifiIpAddress
  readonly property bool wifiOnline: internalWifiOnline
  property int wifiScanCooldownMs: defaultWifiScanCooldownMs

  signal connectionStateChanged
  signal wifiRadioStateChanged

  // Command helpers
  function prepareCommand(arguments, useLowPriority) {
    const baseCommand = ["env", "LC_ALL=C"].concat(arguments || []);
    return useLowPriority ? lowPriorityCommand.concat(baseCommand) : baseCommand;
  }

  function startProcess(processReference) {
    if (!processReference || processReference.running)
      return false;
    processReference.running = true;
    return true;
  }

  function startConnectCommand(commandArguments) {
    if (connectProcess.running)
      return false;
    connectProcess.command = prepareCommand(commandArguments, false);
    connectProcess.running = true;
    return true;
  }

  // Connection operations
  function activateConnection(connectionId, interfaceName) {
    const validatedConnectionId = String(connectionId || "").trim();
    Logger.log("NetworkService", `activateConnection(id=${validatedConnectionId})`);
    if (!validatedConnectionId)
      return;
    const validatedInterfaceName = String(interfaceName || "") || firstWifiInterface();
    startConnectCommand(["nmcli", "connection", "up", "id", validatedConnectionId, "ifname", validatedInterfaceName]);
  }

  function connectToWifi(ssid, password, interfaceName, saveConnection, connectionName) {
    const validatedInterfaceName = String(interfaceName || "") || firstWifiInterface();
    const cleanedSsid = (typeof ssid === "string" ? ssid : String(ssid || "")).trim();
    Logger.log("NetworkService", `connectToWifi(ssid=${cleanedSsid}, iface=${validatedInterfaceName}, save=${!!saveConnection})`);
    if (!cleanedSsid)
      return;
    if (saveConnection && String(connectionName || "")) {
      startConnectCommand(["nmcli", "connection", "add", "type", "wifi", "ifname", validatedInterfaceName, "con-name", String(connectionName), "ssid", cleanedSsid]);
      return;
    }
    const passwordString = String(password || "");
    const command = passwordString ? ["nmcli", "device", "wifi", "connect", cleanedSsid, "password", passwordString, "ifname", validatedInterfaceName] : ["nmcli", "device", "wifi", "connect", cleanedSsid, "ifname", validatedInterfaceName];
    startConnectCommand(command);
  }

  function disconnectInterface(interfaceName) {
    const device = deviceByInterface(interfaceName);
    const deviceType = (device || {}).type || "";
    if (deviceType === "ethernet")
      OSDService.showInfo(qsTr("Ethernet turned off"));
    Logger.log("NetworkService", `disconnecting ${interfaceName} (type: ${deviceType})`);
    startConnectCommand(["nmcli", "device", "disconnect", interfaceName]);
  }

  function disconnectWifi() {
    const interfaceName = firstWifiInterface();
    if (interfaceName)
      disconnectInterface(interfaceName);
  }

  function forgetWifiConnection(connectionId) {
    const idString = String(connectionId || "");
    const command = isUuid(idString) ? ["nmcli", "connection", "delete", "uuid", idString] : ["nmcli", "connection", "delete", "id", idString];
    forgetProcess.command = prepareCommand(command, false);
    forgetProcess.connectionId = idString;
    Logger.log("NetworkService", `forgetting connection: ${idString}`);
    startProcess(forgetProcess);
  }

  function setWifiRadioEnabled(enabled) {
    OSDService.showInfo(enabled ? qsTr("Wi-Fi turned on") : qsTr("Wi-Fi turned off"));
    Logger.log("NetworkService", `setting Wi-Fi radio: ${enabled ? "on" : "off"}`);
    startConnectCommand(["nmcli", "radio", "wifi", enabled ? "on" : "off"]);
  }

  function toggleWifiRadio() {
    setWifiRadioEnabled(!internalWifiRadioEnabled);
  }

  // Query helpers
  function deviceByInterface(interfaceName) {
    for (const device of internalDeviceList) {
      if (device.interface === interfaceName)
        return device;
    }
    return null;
  }

  function firstWifiInterface() {
    for (const device of internalDeviceList) {
      if (device.type === "wifi")
        return device.interface || "";
    }
    return "";
  }

  function isUuid(value) {
    return uuidRegex.test(String(value || ""));
  }

  function chooseActiveDevice(devicesList) {
    if (!devicesList?.length)
      return null;
    let ethernetDevice = null;
    let wifiDevice = null;
    for (const device of devicesList) {
      if (!isConnectedDevice(device))
        continue;
      if (!ethernetDevice && device.type === "ethernet")
        ethernetDevice = device;
      else if (!wifiDevice && device.type === "wifi")
        wifiDevice = device;
    }
    return ethernetDevice || wifiDevice || null;
  }

  function isConnectedDevice(device) {
    const hasValidName = !!(device?.connectionName?.trim() && device.connectionName.trim() !== "--");
    return isConnectedState(device?.state) || hasValidName;
  }

  function isConnectedState(stateValue) {
    const stateString = String(stateValue || "").trim().toLowerCase();
    // Numeric: >=100 for connected
    const numMatch = stateString.match(/^(\d+)/);
    if (numMatch)
      return parseInt(numMatch[1], 10) >= 100;
    // String: contains "connected", no "disconnected"/"connecting"
    return stateString.includes("connected") && !stateString.includes("disconnected") && !stateString.includes("connecting");
  }

  function inferBandLabel(frequencyString) {
    const frequencyMhz = parseInt(String(frequencyString || ""), 10);
    if (!frequencyMhz || frequencyMhz <= 0)
      return "";
    if (frequencyMhz >= 2400 && frequencyMhz <= 2500)
      return "2.4";
    if (frequencyMhz >= 4900 && frequencyMhz <= 5900)
      return "5";
    if (frequencyMhz >= 5925 && frequencyMhz <= 7125)
      return "6";
    return "";
  }

  function signalFromBars(barsString) {
    const barCount = (String(barsString || "").match(/[▂▄▆█]/g) || []).length;
    return Math.max(0, Math.min(100, barCount * 25));
  }

  function stripCidr(ipAddress) {
    const addressString = String(ipAddress || "");
    const slashIndex = addressString.indexOf("/");
    return slashIndex > 0 ? addressString.substring(0, slashIndex) : addressString;
  }

  // Cooldown check
  function isCooldownActive(lastTimeMs, cooldownDurationMs, currentTimeMs) {
    const nowTimeMs = currentTimeMs ?? Date.now();
    return nowTimeMs - (lastTimeMs || 0) < cooldownDurationMs;
  }

  // Parsing functions (robust with guards)
  function splitNmcliLine(line) {
    const fields = [];
    let currentField = "";
    let escapeMode = false;
    for (let charIndex = 0; charIndex < line.length; charIndex++) {
      const character = line[charIndex];
      if (escapeMode) {
        currentField += character;
        escapeMode = false;
      } else if (character === "\\") {
        escapeMode = true;
      } else if (character === ":") {
        fields.push(currentField);
        currentField = "";
      } else {
        currentField += character;
      }
    }
    fields.push(currentField);
    return fields;
  }

  function unescapeNmcli(value) {
    return String(value || "").replace(/\\:/g, ":").replace(/\\\\/g, "\\");
  }

  function parseDeviceListMultiline(outputText) {
    const lines = String(outputText || "").split(/\n+/);
    const devicesList = [];
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
    for (const line of lines) {
      const trimmedLine = line.trim();
      if (!trimmedLine)
        continue;
      const colonPosition = trimmedLine.indexOf(":");
      if (colonPosition <= 0)
        continue;
      const key = trimmedLine.substring(0, colonPosition).trim();
      const value = trimmedLine.substring(colonPosition + 1).trim();
      if (key === "GENERAL.DEVICE" || key === "DEVICE") {
        if (currentDevice.interface)
          devicesList.push(currentDevice);
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
      } else if (key === "GENERAL.TYPE" || key === "TYPE") {
        currentDevice.type = value;
      } else if (key === "GENERAL.STATE" || key === "STATE") {
        currentDevice.state = value;
      } else if (key === "GENERAL.CONNECTION" || key === "CONNECTION") {
        currentDevice.connectionName = value;
      } else if (key === "GENERAL.CON-UUID" || key === "CON-UUID") {
        currentDevice.connectionUuid = value;
      } else if (key === "GENERAL.HWADDR" || key === "HWADDR") {
        currentDevice.mac = value;
      } else if (key.includes("IP4.ADDRESS")) {
        currentDevice.ip4 = value;
      } else if (key.includes("IP6.ADDRESS")) {
        currentDevice.ip6 = value;
      }
    }
    if (currentDevice.interface)
      devicesList.push(currentDevice);
    return devicesList;
  }

  function parseWifiListMultiline(outputText) {
    const lines = String(outputText || "").split(/\n+/);
    const accessPointsList = [];
    let currentAccessPoint = {
      ssid: "",
      bssid: "",
      signal: 0,
      security: "",
      freq: "",
      band: "",
      connected: false
    };
    for (const rawLine of lines) {
      const trimmedLine = rawLine.trim();
      if (!trimmedLine)
        continue;
      const colonPosition = trimmedLine.indexOf(":");
      if (colonPosition <= 0)
        continue;
      const key = trimmedLine.substring(0, colonPosition).trim();
      const value = trimmedLine.substring(colonPosition + 1).trim();
      if (key === "IN-USE") {
        if (currentAccessPoint.ssid || currentAccessPoint.bssid)
          accessPointsList.push(currentAccessPoint);
        currentAccessPoint = {
          ssid: "",
          bssid: "",
          signal: 0,
          security: "",
          freq: "",
          band: "",
          connected: value === "*"
        };
      } else if (key === "SSID") {
        currentAccessPoint.ssid = value;
      } else if (key === "BSSID") {
        currentAccessPoint.bssid = value;
      } else if (key === "SIGNAL") {
        currentAccessPoint.signal = parseInt(value, 10) || 0;
      } else if (key === "BARS") {
        currentAccessPoint.bars = value;
      } else if (key === "SECURITY") {
        currentAccessPoint.security = value;
      } else if (key === "FREQ") {
        currentAccessPoint.freq = value;
      }
    }
    if (currentAccessPoint.ssid || currentAccessPoint.bssid)
      accessPointsList.push(currentAccessPoint);
    // Backfill signal from bars if zero
    for (const accessPoint of accessPointsList) {
      if (accessPoint.signal === 0 && accessPoint.bars) {
        accessPoint.signal = signalFromBars(accessPoint.bars);
      }
    }
    return accessPointsList;
  }

  function dedupeWifiNetworks(entries) {
    if (!entries?.length)
      return [];
    const networksBySsid = {};
    for (const entry of entries) {
      const ssid = String(entry.ssid || "").trim();
      if (!ssid || ssid === "--")
        continue;
      const bandLabel = inferBandLabel(entry.freq || "");
      const signalStrength = entry.signal || (entry.bars ? signalFromBars(entry.bars) : 0) || (entry.connected ? 60 : 0);
      if (!networksBySsid[ssid]) {
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
        const existing = networksBySsid[ssid];
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
    const dedupedList = Object.values(networksBySsid);
    dedupedList.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || (b.signal || 0) - (a.signal || 0));
    return dedupedList;
  }

  // State update
  function updateDerivedState() {
    const previousLinkType = linkType;
    let wifiInterface = "", ethernetInterface = "", wifiConnected = false, ethernetConnected = false, wifiIpAddress = "", ethernetIpAddress = "";
    for (const device of internalDeviceList) {
      const isDeviceConnected = isConnectedDevice(device);
      if (device.type === "wifi") {
        wifiInterface = device.interface || wifiInterface;
        wifiConnected = wifiConnected || isDeviceConnected;
        if (device.ip4)
          wifiIpAddress = stripCidr(device.ip4);
      } else if (device.type === "ethernet") {
        ethernetInterface = device.interface || ethernetInterface;
        ethernetConnected = ethernetConnected || isDeviceConnected;
        if (device.ip4)
          ethernetIpAddress = stripCidr(device.ip4);
      }
    }
    internalWifiInterface = wifiInterface;
    internalWifiOnline = wifiConnected;
    internalWifiIpAddress = wifiIpAddress;
    internalEthernetInterface = ethernetInterface;
    internalEthernetOnline = ethernetConnected;
    internalEthernetIpAddress = ethernetIpAddress;
    linkType = ethernetConnected ? "ethernet" : (wifiConnected ? "wifi" : "disconnected");
    if (previousLinkType !== linkType)
      connectionStateChanged();
  }

  function applySavedFlags() {
    const savedSsidsSet = new Set((internalSavedWifiConnections || []).map(saved => (saved.ssid || saved.name) || "").filter(Boolean));
    let activeSsid = null;
    for (const accessPoint of internalWifiAccessPoints) {
      if (accessPoint?.connected && accessPoint.ssid) {
        activeSsid = accessPoint.ssid;
        break;
      }
    }
    if (!activeSsid) {
      const activeDevice = chooseActiveDevice(internalDeviceList);
      if (activeDevice?.type === "wifi" && isConnectedState(activeDevice.state)) {
        activeSsid = activeDevice.connectionName || null;
      }
    }
    internalWifiAccessPoints = (internalWifiAccessPoints || []).map(function (accessPoint) {
      const updatedAccessPoint = Object.assign({}, accessPoint || {});
      updatedAccessPoint.saved = savedSsidsSet.has(updatedAccessPoint.ssid);
      if (activeSsid && !updatedAccessPoint.connected) {
        updatedAccessPoint.connected = updatedAccessPoint.ssid === activeSsid;
      }
      return updatedAccessPoint;
    }).sort(function (a, b) {
      return (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || (b.signal || 0) - (a.signal || 0);
    });
  }

  // Refresh/scan
  function refreshAll() {
    refreshDeviceList(false);
    if (internalWifiInterface && internalWifiRadioEnabled)
      scanWifi(internalWifiInterface);
    startProcess(wifiRadioProcess);
  }

  function refreshDeviceList(forceRefresh) {
    const currentTimeMs = Date.now();
    if (!forceRefresh && isCooldownActive(lastDeviceRefreshTimeMs, deviceRefreshCooldownMs, currentTimeMs))
      return;
    lastDeviceRefreshTimeMs = currentTimeMs;
    if (!deviceShowProcess.running)
      startProcess(deviceShowProcess);
  }

  function scanWifi(wifiInterface, forceScan) {
    const validatedInterface = wifiInterface || internalWifiInterface || firstWifiInterface();
    if (!validatedInterface || internalScanning || !internalWifiRadioEnabled)
      return;
    const device = deviceByInterface(validatedInterface);
    if (device?.state?.includes("unavailable"))
      return;
    const currentTimeMs = Date.now();
    if (!forceScan && isCooldownActive(lastWifiScanTimeMs, wifiScanCooldownMs, currentTimeMs))
      return;
    Logger.log("NetworkService", `scanning Wi-Fi on ${validatedInterface}${forceScan ? " (forced)" : ""}`);
    internalScanning = true;
    const rescanOption = forceScan ? "yes" : "auto";
    wifiListProcess.command = prepareCommand(["nmcli", "-m", "multiline", "-f", "IN-USE,SSID,BSSID,SIGNAL,BARS,SECURITY,FREQ", "device", "wifi", "list", "ifname", validatedInterface, "--rescan", rescanOption], true);
    startProcess(wifiListProcess);
  }

  // Lifecycle
  Component.onCompleted: {
    internalReady = true;
    refreshAll();
    startProcess(savedConnectionsProcess);
  }

  onConnectionStateChanged: {
    Logger.log("NetworkService", `link: ${linkType} (wifiIf: ${internalWifiInterface || "-"}, ethIf: ${internalEthernetInterface || "-"})`);
    applySavedFlags();
    if (linkType === "wifi") {
      const interfaceName = internalWifiInterface || firstWifiInterface();
      if (interfaceName)
        scanWifi(interfaceName, true);
    }
  }

  onWifiRadioStateChanged: {
    Logger.log("NetworkService", `Wi-Fi radio: ${internalWifiRadioEnabled ? "enabled" : "disabled"}`);
  }

  // Timers for debouncing/restart
  Timer {
    id: monitorDebounceTimer
    interval: 500
    repeat: false
    running: false
    onTriggered: {
      network.refreshDeviceList(true);
      const interfaceName = network.internalWifiInterface || network.firstWifiInterface();
      if (interfaceName && network.internalWifiRadioEnabled && !network.internalScanning) {
        network.scanWifi(interfaceName);
      }
    }
  }

  Timer {
    id: monitorRestartTimer
    interval: 3000
    repeat: false
    running: false
    onTriggered: {
      network.startProcess(monitorProcess);
    }
  }

  // Processes
  Process {
    id: monitorProcess
    command: network.prepareCommand(["nmcli", "monitor"], true)
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: {
        if (monitorDebounceTimer.running)
          monitorDebounceTimer.stop();
        monitorDebounceTimer.start();
      }
    }
    Component.onCompleted: {
      network.startProcess(monitorProcess);
    }
    onRunningChanged: {
      if (!running && !monitorRestartTimer.running)
        monitorRestartTimer.start();
    }
  }

  Process {
    id: deviceShowProcess
    command: network.prepareCommand(["nmcli", "-m", "multiline", "-f", "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,GENERAL.CON-UUID,GENERAL.HWADDR,IP4.ADDRESS,IP6.ADDRESS", "device", "show"], true)
    stdout: StdioCollector {
      onStreamFinished: {
        network.internalDeviceList = network.parseDeviceListMultiline(text);
        network.updateDerivedState();
        const activeDevice = network.chooseActiveDevice(network.internalDeviceList);
        const summary = activeDevice ? `${activeDevice.interface}/${activeDevice.type}` : "none";
        Logger.log("NetworkService", `devices: ${network.internalDeviceList.length}, active: ${summary}, link: ${network.linkType}`);
        network.applySavedFlags();
      }
    }
  }

  Process {
    id: wifiListProcess
    stdout: StdioCollector {
      onStreamFinished: {
        network.internalScanning = false;
        const parsedAccessPoints = network.parseWifiListMultiline(text);
        network.internalWifiAccessPoints = network.dedupeWifiNetworks(parsedAccessPoints);
        network.applySavedFlags();
        network.lastWifiScanTimeMs = Date.now();
        network.refreshDeviceList(true);
        let activeSsid = null;
        let activeSignal = null;
        for (const accessPoint of network.internalWifiAccessPoints) {
          if (accessPoint?.connected && accessPoint.ssid) {
            activeSsid = accessPoint.ssid;
            activeSignal = accessPoint.signal;
            break;
          }
        }
        Logger.log("NetworkService", `Wi-Fi: ${network.internalWifiAccessPoints.length}${activeSsid ? `, active: ${activeSsid} (${activeSignal || 0}%)` : " (no active)"}`);
      }
    }
  }

  Process {
    id: wifiRadioProcess
    command: network.prepareCommand(["nmcli", "-t", "-f", "WIFI", "general"], false)
    stdout: StdioCollector {
      onStreamFinished: {
        const statusString = String(text || "").trim().toLowerCase();
        const radioEnabled = statusString.includes("enabled") || statusString === "yes" || statusString === "on";
        if (network.internalWifiRadioEnabled !== radioEnabled) {
          network.internalWifiRadioEnabled = radioEnabled;
          network.wifiRadioStateChanged();
        }
      }
    }
  }

  Process {
    id: connectProcess
    stdout: StdioCollector {
      onStreamFinished: {
        network.refreshDeviceList(true);
        network.startProcess(savedConnectionsProcess);
        network.startProcess(wifiRadioProcess);
      }
    }
  }

  Process {
    id: savedConnectionsProcess
    command: network.prepareCommand(["nmcli", "-t", "-e", "yes", "-f", "NAME,TYPE", "connection", "show"], false)
    stdout: StdioCollector {
      onStreamFinished: {
        const connectionsList = [];
        const lines = String(text || "").trim().split(/\n+/);
        for (const line of lines) {
          const trimmedLine = line.trim();
          if (!trimmedLine)
            continue;
          const fields = network.splitNmcliLine(trimmedLine);
          if (fields.length >= 2 && fields[1] === "802-11-wireless") {
            const name = network.unescapeNmcli(fields[0]);
            connectionsList.push({
              ssid: name,
              name: name
            });
          }
        }
        network.internalSavedWifiConnections = connectionsList;
        network.applySavedFlags();
      }
    }
  }

  Process {
    id: forgetProcess
    property string connectionId: ""
    stdout: StdioCollector {
      onStreamFinished: {
        Logger.log("NetworkService", `forgot connection: ${forgetProcess.connectionId || "<unknown>"}`);
        network.refreshAll();
        network.startProcess(savedConnectionsProcess);
      }
    }
  }
}
