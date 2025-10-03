pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
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
  property string connectingSsid: ""  // Track SSID currently being connected

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
  signal connectionError(string ssid, string errorMessage)

  // Command helpers
  function prepareCommand(args, useLowPriority) {
    const baseCommand = ["env", "LC_ALL=C"].concat(args || []);
    return useLowPriority ? lowPriorityCommand.concat(baseCommand) : baseCommand;
  }

  function trim(value) {
    return String(value || "").trim();
  }

  function startProcess(processRef) {
    if (!processRef || processRef.running)
      return false;
    processRef.running = true;
    return true;
  }

  function startConnectCommand(commandArguments) {
    if (connectProcess.running)
      return false;
    const cmd = prepareCommand(commandArguments, false);
    Logger.log("NetworkService", `Starting connect command: ${cmd.join(" ")}`);
    connectProcess.command = cmd;
    connectProcess.running = true;
    return true;
  }

  // Connection operations
  function activateConnection(connectionId, interfaceName) {
    const validId = trim(connectionId);
    const validIface = trim(interfaceName) || firstWifiInterface();
    Logger.log("NetworkService", `activateConnection(id=${validId}, iface=${validIface})`);
    if (!validId)
      return;
    startConnectCommand(["nmcli", "connection", "up", "uuid", validId, "ifname", validIface]);
  }

  function connectToWifi(ssid, password, interfaceName, saveConnection, connectionName) {
    const validIface = trim(interfaceName) || firstWifiInterface();
    const cleanSsid = trim(ssid);
    Logger.log("NetworkService", `connectToWifi(ssid=${cleanSsid}, iface=${validIface})`);
    if (!cleanSsid)
      return;
    network.connectingSsid = cleanSsid;
    const pwd = String(password || "");

    if (pwd) {
      const esc = s => s.replace(/'/g, "'\\''");

      // First, delete any old temp connections for this SSID to avoid conflicts
      const tempConnections = (network.savedWifiAps || []).filter(conn => conn?.ssid?.startsWith(`temp_${cleanSsid}_`) || conn?.name?.startsWith(`temp_${cleanSsid}_`));

      let cleanupCmd = "";
      if (tempConnections.length > 0) {
        const deleteCommands = tempConnections.map(conn => `nmcli connection delete uuid '${esc(conn.connectionId)}'`).join(" 2>/dev/null; ");
        cleanupCmd = deleteCommands + " 2>/dev/null; ";
        Logger.log("NetworkService", `Cleaning up ${tempConnections.length} old temp connection(s)`);
      }

      // Use nmcli dev wifi connect with proper escaping
      const connectCmd = `nmcli dev wifi connect '${esc(cleanSsid)}' password '${esc(pwd)}'`;
      const shellCmd = cleanupCmd + connectCmd;

      Logger.log("NetworkService", `Connecting with password (length: ${pwd.length}) via dev wifi connect`);
      startConnectCommand(["sh", "-c", shellCmd]);
    } else {
      startConnectCommand(["nmcli", "device", "wifi", "connect", cleanSsid, "ifname", validIface]);
    }
  }

  function disconnectInterface(interfaceName) {
    const device = deviceByInterface(interfaceName);
    const deviceType = (device || {}).type || "";
    Logger.log("NetworkService", `disconnecting ${interfaceName} (type: ${deviceType})`);
    startConnectCommand(["nmcli", "device", "disconnect", interfaceName]);
  }

  function disconnectWifi() {
    const interfaceName = firstWifiInterface();
    if (interfaceName)
      disconnectInterface(interfaceName);
  }

  function forgetWifiConnection(connectionId) {
    const idString = trim(connectionId);
    const command = isUuid(idString) ? ["nmcli", "connection", "delete", "uuid", idString] : ["nmcli", "connection", "delete", "id", idString];
    forgetProcess.command = prepareCommand(command, false);
    forgetProcess.connectionId = idString;
    Logger.log("NetworkService", `forgetting connection: ${idString}`);
    startProcess(forgetProcess);
  }

  function setWifiRadioEnabled(enabled) {
    Logger.log("NetworkService", `setting Wi-Fi radio: ${enabled ? "on" : "off"}`);
    startConnectCommand(["nmcli", "radio", "wifi", enabled ? "on" : "off"]);
  }

  function toggleWifiRadio() {
    setWifiRadioEnabled(!internalWifiRadioEnabled);
  }

  // Query helpers
  function deviceByInterface(interfaceName) {
    return internalDeviceList.find(device => device.interface === interfaceName) || null;
  }

  function firstWifiInterface() {
    const wifiDevice = internalDeviceList.find(device => device.type === "wifi");
    return wifiDevice?.interface || "";
  }

  function isUuid(value) {
    return uuidRegex.test(String(value || ""));
  }

  function chooseActiveDevice(devicesList) {
    if (!devicesList?.length)
      return null;
    const connected = devicesList.filter(isConnectedDevice);
    return connected.find(d => d.type === "ethernet") || connected.find(d => d.type === "wifi") || null;
  }

  function isConnectedDevice(device) {
    const hasValidName = !!(device?.connectionName?.trim() && device.connectionName.trim() !== "--");
    return isConnectedState(device?.state) || hasValidName;
  }

  function isConnectedState(stateValue) {
    const stateString = String(stateValue || "").trim().toLowerCase();
    const numMatch = stateString.match(/^(\d+)/);
    if (numMatch)
      return parseInt(numMatch[1], 10) >= 100;
    return stateString.includes("connected") && !stateString.includes("disconnected") && !stateString.includes("connecting");
  }

  function inferBandLabel(frequencyString) {
    const freq = parseInt(String(frequencyString || ""), 10);
    if (!freq || freq <= 0)
      return "";
    if (freq >= 2400 && freq <= 2500)
      return "2.4";
    if (freq >= 4900 && freq <= 5900)
      return "5";
    if (freq >= 5925 && freq <= 7125)
      return "6";
    return "";
  }

  function getBandColor(band) {
    return band === "6" ? "#A6E3A1" : band === "5" ? "#89B4FA" : "#CDD6F4";
  }

  function getWifiIcon(band, signal) {
    const s = Math.max(0, Math.min(100, signal | 0));
    const icons = band === "6" ? ["�", "�", "�", "�"] : ["󰤟", "󰤢", "󰤥", "󰤨"];
    return s >= 95 ? icons[3] : s >= 80 ? icons[2] : s >= 50 ? icons[1] : icons[0];
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
    for (const character of line) {
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
    const savedSsidsSet = new Set((internalSavedWifiConnections || []).map(saved => saved.ssid || saved.name).filter(Boolean));
    const activeSsid = internalWifiAccessPoints.find(ap => ap?.connected)?.ssid || ((() => {
          const activeDevice = chooseActiveDevice(internalDeviceList);
          return (activeDevice?.type === "wifi" && isConnectedState(activeDevice.state)) ? activeDevice.connectionName : null;
        })());

    internalWifiAccessPoints = (internalWifiAccessPoints || []).map(ap => {
      const updated = Object.assign({}, ap);
      updated.saved = savedSsidsSet.has(ap.ssid);
      updated.connected = ap.connected || (activeSsid && ap.ssid === activeSsid);
      return updated;
    }).sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || (b.signal || 0) - (a.signal || 0));
  }

  // Refresh/scan
  function refreshAll() {
    refreshDeviceList(false);
    const wifiIface = internalWifiInterface || firstWifiInterface();
    if (wifiIface && internalWifiRadioEnabled)
      scanWifi(wifiIface);
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

    onRunningChanged: {
      Logger.log("NetworkService", `connectProcess running: ${running}`);
    }

    stdout: StdioCollector {
      onStreamFinished: {
        const output = String(text || "").trim();
        const outputLength = output.length;
        Logger.log("NetworkService", "Connect stdout length: " + outputLength);
        if (outputLength > 0) {
          // Log first 200 chars to avoid issues with long output
          const preview = output.substring(0, 200);
          Logger.log("NetworkService", "Connect stdout: " + preview);

          // Check if connection was successful
          if (output.includes("successfully activated") || output.includes("Connection successfully activated")) {
            Logger.log("NetworkService", "Connection successful!");
          }
        } else {
          Logger.log("NetworkService", "Connect stdout: (empty)");
        }
        network.refreshDeviceList(true);
        network.startProcess(savedConnectionsProcess);
        network.startProcess(wifiRadioProcess);

        // Force WiFi scan after connection to update active network immediately
        const wifiIface = network.wifiInterface || network.firstWifiInterface();
        if (wifiIface) {
          Logger.log("NetworkService", "Forcing WiFi scan after connection");
          network.scanWifi(wifiIface, true);
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim().length > 0) {
          const errorText = text.trim();
          Logger.log("NetworkService", `Connect command ERROR: ${errorText}`);

          // Check for common password/authentication errors
          const lowerError = errorText.toLowerCase();
          let errorMessage = "Connection failed";

          if (lowerError.includes("secrets were required") || lowerError.includes("no secrets") || lowerError.includes("802-1x")) {
            errorMessage = "Wrong password";
          } else if (lowerError.includes("timeout") || lowerError.includes("activation failed")) {
            errorMessage = "Connection timeout";
          } else if (lowerError.includes("not found")) {
            errorMessage = "Network not found";
          }

          // Emit error signal with SSID
          network.connectionError(network.connectingSsid, errorMessage);
        }
      }
    }
  }

  Process {
    id: savedConnectionsProcess
    command: network.prepareCommand(["nmcli", "-t", "-e", "yes", "-f", "NAME,TYPE,UUID", "connection", "show"], false)
    stdout: StdioCollector {
      onStreamFinished: {
        const connectionsList = [];
        const lines = String(text || "").trim().split(/\n+/);
        for (const line of lines) {
          const trimmedLine = line.trim();
          if (!trimmedLine)
            continue;
          const fields = network.splitNmcliLine(trimmedLine);
          if (fields.length >= 3 && fields[1] === "802-11-wireless") {
            const name = network.unescapeNmcli(fields[0]);
            const uuid = network.unescapeNmcli(fields[2]);
            connectionsList.push({
              ssid: name,
              name: name,
              connectionId: uuid
            });
          }
        }
        Logger.log("NetworkService", `Saved WiFi connections: ${JSON.stringify(connectionsList)}`);
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
