pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: root

  // Internal state (mutable)
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
  readonly property var deviceList: _deviceList
  property int deviceRefreshCooldownMs: defaultDeviceRefreshCooldownMs
  readonly property string ethernetInterface: _ethernetInterface
  readonly property string ethernetIpAddress: _ethernetIp
  readonly property bool ethernetOnline: _ethernetOnline
  property string linkType: "disconnected"
  readonly property var lowPriorityCommand: ["nice", "-n", "19", "ionice", "-c3"]
  readonly property bool networkingEnabled: _networkingEnabled
  readonly property bool ready: _ready
  readonly property var savedWifiAps: _savedWifiConns
  readonly property bool scanning: _scanning
  readonly property var uuidRegex: /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/
  readonly property var wifiAps: _wifiAps
  readonly property string wifiInterface: _wifiInterface
  readonly property string wifiIpAddress: _wifiIp
  readonly property bool wifiOnline: _wifiOnline
  readonly property bool wifiRadioEnabled: _wifiRadioEnabled
  property int wifiScanCooldownMs: defaultWifiScanCooldownMs

  signal connectionError(string ssid, string errorMessage)
  signal connectionStateChanged
  signal wifiRadioStateChanged

  function _safeStop(obj) {
    try {
      obj.running = false;
    } catch (_) {}
    try {
      obj.stop?.();
    } catch (_) {}
  }

  function activateConnection(connectionId, interfaceName) {
    const id = trim(connectionId);
    const iface = trim(interfaceName) || firstWifiInterface();
    if (!id)
      return;
    startConnectCommand(["nmcli", "connection", "up", "uuid", id, "ifname", iface]);
  }

  function applySavedFlags() {
    const savedSsidsSet = new Set((_savedWifiConns || []).map(saved => saved.ssid || saved.name).filter(Boolean));
    const connectedAp = _wifiAps.find(ap => ap?.connected);
    const activeDevice = chooseActiveDevice(_deviceList);
    const activeSsid = connectedAp?.ssid || (activeDevice?.type === "wifi" && isConnectedState(activeDevice?.state) ? activeDevice.connectionName : null);

    _wifiAps = (_wifiAps || []).map(ap => {
      const updated = Object.assign({}, ap);
      updated.saved = savedSsidsSet.has(ap.ssid);
      updated.connected = ap.connected || (activeSsid && ap.ssid === activeSsid);
      return updated;
    }).sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || (b.signal || 0) - (a.signal || 0));
  }

  function chooseActiveDevice(devicesList) {
    if (!devicesList?.length)
      return null;
    const connected = devicesList.filter(isConnectedDevice);
    return connected.find(d => d.type === "ethernet") || connected.find(d => d.type === "wifi") || null;
  }

  function connectToWifi(ssid, password, interfaceName, saveConnection, connectionName) {
    const iface = trim(interfaceName) || firstWifiInterface();
    const cleanSsid = trim(ssid);
    if (!cleanSsid)
      return;

    root.connectingSsid = cleanSsid;
    const pwd = String(password || "");

    if (pwd) {
      const esc = s => s.replace(/'/g, "'\\''");
      const tempConns = (root._savedWifiConns || []).filter(c => c?.ssid?.startsWith(`temp_${cleanSsid}_`) || c?.name?.startsWith(`temp_${cleanSsid}_`));

      let cleanup = "";
      if (tempConns.length > 0) {
        cleanup = tempConns.map(c => `nmcli connection delete uuid '${esc(c.connectionId)}'`).join(" 2>/dev/null; ") + " 2>/dev/null; ";
      }

      const connect = `nmcli dev wifi connect '${esc(cleanSsid)}' password '${esc(pwd)}'`;
      startConnectCommand(["sh", "-c", cleanup + connect]);
    } else {
      startConnectCommand(["nmcli", "device", "wifi", "connect", cleanSsid, "ifname", iface]);
    }
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

  // Query helpers
  function deviceByInterface(interfaceName) {
    return _deviceList.find(device => device.interface === interfaceName) || null;
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

  function firstWifiInterface() {
    const wifiDevice = _deviceList.find(device => device.type === "wifi");
    return wifiDevice?.interface || "";
  }

  function forgetWifiConnection(connectionId) {
    const idString = trim(connectionId);
    const command = isUuid(idString) ? ["nmcli", "connection", "delete", "uuid", idString] : ["nmcli", "connection", "delete", "id", idString];
    forgetProcess.command = prepareCommand(command, false);
    forgetProcess.connectionId = idString;
    Logger.log("NetworkService", `forgetting connection: ${idString}`);
    startProcess(forgetProcess);
  }

  function getBandColor(band) {
    return band === "6" ? "#A6E3A1" : band === "5" ? "#89B4FA" : "#CDD6F4";
  }

  function getWifiIcon(band, signal) {
    const s = Math.max(0, Math.min(100, signal | 0));
    const icons = band === "6" ? ["�", "�", "�", "�"] : ["󰤟", "󰤢", "󰤥", "󰤨"];
    return s >= 95 ? icons[3] : s >= 80 ? icons[2] : s >= 50 ? icons[1] : icons[0];
  }

  function inferBandLabel(frequencyString) {
    const freq = parseInt(String(frequencyString || ""), 10);
    if (freq >= 2400 && freq <= 2500)
      return "2.4";
    if (freq >= 4900 && freq <= 5900)
      return "5";
    if (freq >= 5925 && freq <= 7125)
      return "6";
    return "";
  }

  function isConnectedDevice(device) {
    const hasValidName = !!(device?.connectionName?.trim() && device.connectionName.trim() !== "--");
    return isConnectedState(device?.state) || hasValidName;
  }

  function isConnectedState(stateValue) {
    const stateString = String(stateValue || "").trim().toLowerCase();
    const stateNum = parseInt(stateString.match(/^\d+/)?.[0] || "0", 10);
    if (stateNum >= 100)
      return true;
    return stateString.includes("connected") && !stateString.includes("disconnected") && !stateString.includes("connecting");
  }

  // Cooldown check
  function isCooldownActive(lastTimeMs, cooldownDurationMs, currentTimeMs) {
    const nowTimeMs = currentTimeMs ?? Date.now();
    return nowTimeMs - (lastTimeMs || 0) < cooldownDurationMs;
  }

  function isUuid(value) {
    return uuidRegex.test(String(value || ""));
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

  function prepareCommand(args, useLowPriority) {
    const base = ["env", "LC_ALL=C"].concat(args || []);
    return useLowPriority ? lowPriorityCommand.concat(base) : base;
  }

  // Refresh/scan
  function refreshAll() {
    refreshDeviceList(false);
    const wifiIface = _wifiInterface || firstWifiInterface();
    if (wifiIface && _wifiRadioEnabled)
      scanWifi(wifiIface);
    startProcess(wifiRadioProcess);
    startProcess(networkingProcess);
  }

  function refreshDeviceList(forceRefresh) {
    const currentTimeMs = Date.now();
    if (!forceRefresh && isCooldownActive(_lastDeviceRefreshMs, deviceRefreshCooldownMs, currentTimeMs))
      return;
    _lastDeviceRefreshMs = currentTimeMs;
    if (!deviceShowProcess.running)
      startProcess(deviceShowProcess);
  }

  function scanWifi(wifiInterface, forceScan = false) {
    const validatedInterface = wifiInterface || _wifiInterface || firstWifiInterface();
    if (!validatedInterface || _scanning) {
      return;
    }

    // For forced scans (from UI), skip state checks since device may be transitioning
    if (!forceScan && !_wifiRadioEnabled) {
      return;
    }

    if (!forceScan) {
      const device = deviceByInterface(validatedInterface);
      if (device?.state?.includes("unavailable")) {
        return;
      }

      if (isCooldownActive(_lastWifiScanMs, wifiScanCooldownMs, Date.now())) {
        return;
      }
    }

    Logger.log("NetworkService", `scanning Wi-Fi on ${validatedInterface}${forceScan ? " (forced)" : ""}`);
    _scanning = true;
    _lastScanWasForced = forceScan;
    const rescanOption = forceScan ? "yes" : "auto";
    const cmd = ["nmcli", "-m", "multiline", "-f", "IN-USE,SSID,BSSID,SIGNAL,BARS,SECURITY,FREQ", "device", "wifi", "list", "ifname", validatedInterface, "--rescan", rescanOption];
    wifiListProcess.command = prepareCommand(cmd, true);
    startProcess(wifiListProcess);
  }

  function setNetworkingEnabled(enabled) {
    Logger.log("NetworkService", `setting networking: ${enabled ? "on" : "off"}`);
    startConnectCommand(["nmcli", "networking", enabled ? "on" : "off"]);
  }

  function setWifiRadioEnabled(enabled) {
    Logger.log("NetworkService", `setting Wi-Fi radio: ${enabled ? "on" : "off"}`);
    startConnectCommand(["nmcli", "radio", "wifi", enabled ? "on" : "off"]);
  }

  function signalFromBars(barsString) {
    const barCount = (String(barsString || "").match(/[▂▄▆█]/g) || []).length;
    return Math.max(0, Math.min(100, barCount * 25));
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

  function startConnectCommand(args) {
    if (connectProcess.running)
      return false;
    connectProcess.command = prepareCommand(args, false);
    connectProcess.running = true;
    return true;
  }

  function startProcess(proc) {
    if (!proc || proc.running)
      return false;
    proc.running = true;
    return true;
  }

  function stripCidr(ipAddress) {
    const addressString = String(ipAddress || "");
    return addressString.split("/")[0];
  }

  function toggleNetworking() {
    setNetworkingEnabled(!_networkingEnabled);
  }

  function toggleWifiRadio() {
    setWifiRadioEnabled(!_wifiRadioEnabled);
  }

  function trim(value) {
    return String(value || "").trim();
  }

  function unescapeNmcli(value) {
    return String(value || "").replace(/\\:/g, ":").replace(/\\\\/g, "\\");
  }

  // State update
  function updateDerivedState() {
    const previousLinkType = linkType;
    let wifiInterface = "", ethernetInterface = "", wifiConnected = false, ethernetConnected = false, wifiIpAddress = "", ethernetIpAddress = "";

    for (const device of _deviceList) {
      const isConnected = isConnectedDevice(device);
      if (device.type === "wifi") {
        wifiInterface = device.interface || wifiInterface;
        wifiConnected = wifiConnected || isConnected;
        if (device.ip4)
          wifiIpAddress = stripCidr(device.ip4);
      } else if (device.type === "ethernet") {
        ethernetInterface = device.interface || ethernetInterface;
        ethernetConnected = ethernetConnected || isConnected;
        if (device.ip4)
          ethernetIpAddress = stripCidr(device.ip4);
      }
    }

    _wifiInterface = wifiInterface;
    _wifiOnline = wifiConnected;
    _wifiIp = wifiIpAddress;
    _ethernetInterface = ethernetInterface;
    _ethernetOnline = ethernetConnected;
    _ethernetIp = ethernetIpAddress;
    linkType = ethernetConnected ? "ethernet" : (wifiConnected ? "wifi" : "disconnected");

    if (previousLinkType !== linkType)
      connectionStateChanged();
  }

  // Lifecycle
  Component.onCompleted: {
    _ready = true;
    refreshAll();
    startProcess(savedConnectionsProcess);
  }
  Component.onDestruction: {
    _safeStop(monitorDebounceTimer);
    _safeStop(monitorRestartTimer);
    _safeStop(monitorProcess);
    _safeStop(deviceShowProcess);
    _safeStop(wifiListProcess);
    _safeStop(wifiRadioProcess);
    _safeStop(connectProcess);
    _safeStop(savedConnectionsProcess);
    _safeStop(forgetProcess);
  }
  onConnectionStateChanged: {
    Logger.log("NetworkService", `link: ${linkType} (wifiIf: ${_wifiInterface || "-"}, ethIf: ${_ethernetInterface || "-"})`);
    applySavedFlags();
    if (linkType === "wifi") {
      const interfaceName = _wifiInterface || firstWifiInterface();
      if (interfaceName)
        scanWifi(interfaceName, true);
    }
  }
  onWifiRadioStateChanged: {
    Logger.log("NetworkService", `Wi-Fi radio: ${_wifiRadioEnabled ? "enabled" : "disabled"}`);
  }

  // Timers for debouncing/restart
  Timer {
    id: monitorDebounceTimer

    interval: 500
    repeat: false
    running: false

    onTriggered: {
      root.refreshDeviceList(true);
      const interfaceName = root._wifiInterface || root.firstWifiInterface();
      if (interfaceName && root._wifiRadioEnabled && !root._scanning) {
        root.scanWifi(interfaceName);
      }
    }
  }

  Timer {
    id: monitorRestartTimer

    interval: 3000
    repeat: false
    running: false

    onTriggered: {
      root.startProcess(monitorProcess);
    }
  }

  // Processes
  Process {
    id: monitorProcess

    command: root.prepareCommand(["nmcli", "monitor"], true)

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: {
        if (monitorDebounceTimer.running)
          monitorDebounceTimer.stop();
        monitorDebounceTimer.start();
      }
    }

    Component.onCompleted: {
      root.startProcess(monitorProcess);
    }
    onRunningChanged: {
      if (!running && !monitorRestartTimer.running)
        monitorRestartTimer.start();
    }
  }

  Process {
    id: deviceShowProcess

    command: root.prepareCommand(["nmcli", "-m", "multiline", "-f", "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,GENERAL.CON-UUID,GENERAL.HWADDR,IP4.ADDRESS,IP6.ADDRESS", "device", "show"], true)

    stdout: StdioCollector {
      onStreamFinished: {
        root._deviceList = root.parseDeviceListMultiline(text);
        root.updateDerivedState();
        const activeDevice = root.chooseActiveDevice(root._deviceList);
        const summary = activeDevice ? `${activeDevice.interface}/${activeDevice.type}` : "none";
        Logger.log("NetworkService", `devices: ${root._deviceList.length}, active: ${summary}, link: ${root.linkType}`);
        root.applySavedFlags();
      }
    }
  }

  Process {
    id: wifiListProcess

    stdout: StdioCollector {
      onStreamFinished: {
        root._scanning = false;
        const parsedAccessPoints = root.parseWifiListMultiline(text);

        // If forced scan returned 0 results and WiFi is enabled, retry after 2 seconds (radio may still be initializing)
        if (root._lastScanWasForced && parsedAccessPoints.length === 0 && root.wifiRadioEnabled) {
          root._lastScanWasForced = false;
          Qt.callLater(() => {
            const iface = root.wifiInterface || root.firstWifiInterface();
            if (iface)
              root.scanWifi(iface, true);
          }, 2000);
          return;
        }

        root._lastScanWasForced = false;
        root._wifiAps = root.dedupeWifiNetworks(parsedAccessPoints);
        root.applySavedFlags();
        root._lastWifiScanMs = Date.now();
        root.refreshDeviceList(true);
        let activeSsid = null;
        let activeSignal = null;
        for (const accessPoint of root._wifiAps) {
          if (accessPoint?.connected && accessPoint.ssid) {
            activeSsid = accessPoint.ssid;
            activeSignal = accessPoint.signal;
            break;
          }
        }
        Logger.log("NetworkService", `Wi-Fi: ${root._wifiAps.length}${activeSsid ? `, active: ${activeSsid} (${activeSignal || 0}%)` : " (no active)"}`);
      }
    }
  }

  Process {
    id: wifiRadioProcess

    command: root.prepareCommand(["nmcli", "-t", "-f", "WIFI", "general"], false)

    stdout: StdioCollector {
      onStreamFinished: {
        const statusString = String(text || "").trim().toLowerCase();
        const radioEnabled = statusString.includes("enabled") || statusString === "yes" || statusString === "on";
        if (root._wifiRadioEnabled !== radioEnabled) {
          root._wifiRadioEnabled = radioEnabled;
          root.wifiRadioStateChanged();
        }
      }
    }
  }

  Process {
    id: networkingProcess

    command: root.prepareCommand(["nmcli", "networking"], false)

    stdout: StdioCollector {
      onStreamFinished: {
        const statusString = String(text || "").trim().toLowerCase();
        const enabled = statusString.includes("enabled") || statusString === "on" || statusString === "yes";
        if (root._networkingEnabled !== enabled) {
          root._networkingEnabled = enabled;
          Logger.log("NetworkService", `Networking state: ${enabled ? "enabled" : "disabled"}`);
        }
      }
    }
  }

  Process {
    id: connectProcess

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
          root.connectionError(root.connectingSsid, errorMessage);
        }
      }
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
        root.refreshDeviceList(true);
        root.startProcess(savedConnectionsProcess);
        root.startProcess(wifiRadioProcess);
        root.startProcess(networkingProcess);

        // Force WiFi scan after connection to update active network immediately
        // Use longer delay (3s) to ensure WiFi radio has time to scan and populate results
        const wifiIface = root.wifiInterface || root.firstWifiInterface();
        if (wifiIface) {
          Qt.callLater(() => {
            root.scanWifi(wifiIface, true);
          }, 3000);
        }
      }
    }

    onRunningChanged: {
      Logger.log("NetworkService", `connectProcess running: ${running}`);
    }
  }

  Process {
    id: savedConnectionsProcess

    command: root.prepareCommand(["nmcli", "-t", "-e", "yes", "-f", "NAME,TYPE,UUID", "connection", "show"], false)

    stdout: StdioCollector {
      onStreamFinished: {
        const connectionsList = [];
        const lines = String(text || "").trim().split(/\n+/);
        for (const line of lines) {
          const trimmedLine = line.trim();
          if (!trimmedLine)
            continue;
          const fields = root.splitNmcliLine(trimmedLine);
          if (fields.length >= 3 && fields[1] === "802-11-wireless") {
            const name = root.unescapeNmcli(fields[0]);
            const uuid = root.unescapeNmcli(fields[2]);
            connectionsList.push({
              ssid: name,
              name: name,
              connectionId: uuid
            });
          }
        }
        Logger.log("NetworkService", `Saved WiFi connections: ${JSON.stringify(connectionsList)}`);
        root._savedWifiConns = connectionsList;
        root.applySavedFlags();
      }
    }
  }

  Process {
    id: forgetProcess

    property string connectionId: ""

    stdout: StdioCollector {
      onStreamFinished: {
        Logger.log("NetworkService", `forgot connection: ${forgetProcess.connectionId || "<unknown>"}`);
        root.refreshAll();
        root.startProcess(savedConnectionsProcess);
      }
    }
  }
}
