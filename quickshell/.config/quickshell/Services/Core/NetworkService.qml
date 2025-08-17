pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: net

    // === Properties ===
    // readiness
    property bool ready: false

    // debug logging (set true to see verbose logs)
    property bool debug: true

    // backend info

    // devices and networks
    property var devices: []         // list of device objects
    property var wifiNetworks: []    // last scanned wifi networks
    property var activeDevice: null  // currently active device object
    // derived, simplified state (for consumers)
    property string networkStatus: "disconnected"   // "ethernet" | "wifi" | "disconnected"
    property string ethernetInterface: ""
    property bool ethernetConnected: false
    property string ethernetIP: ""
    property string wifiInterface: ""
    property bool wifiConnected: false
    property string wifiIP: ""
    property var savedConnections: []   // array of {ssid}
    property bool wifiRadioEnabled: true

    // scanning / monitor state
    property bool scanning: false
    property int lastWifiScanAt: 0
    property int wifiScanCooldownMs: 10000
    // device refresh cooldown
    property int lastDevicesRefreshAt: 0
    property int deviceRefreshCooldownMs: 1000

    // polling fallback settings
    property bool monitorRunning: false
    property bool usePollingFallback: false
    property int devicePollIntervalMs: 5000
    property int wifiPollIntervalMs: 30000

    property string lastError: ""

    // === Signals ===
    // property change signals are auto-provided by QML
    signal error(string message)
    signal networksUpdated
    signal connectionChanged
    signal wifiRadioChanged

    // === Internal helpers ===
    function _nowMs() {
        return Date.now();
    }

    // Centralized runner for procConnect to avoid overlapping runs
    function _runProcConnect(cmdArray) {
        if (procConnect.running) {
            net._log("[NetworkService] procConnect busy; skipping command", JSON.stringify(cmdArray));
            return false;
        }
        try {
            procConnect.command = cmdArray;
            procConnect.running = true;
            return true;
        } catch (e) {
            net._setError("Unable to start command: " + e);
            return false;
        }
    }

    function _setError(msg) {
        net.lastError = msg;
        net.error(msg);
        console.log("[NetworkService] Error:", msg);
    }

    // Lightweight debug logger
    function _log() {
        if (!net.debug)
            return;
        try {
            console.log.apply(console, arguments);
        } catch (e) {}
    }

    // Trim CIDR suffix from IP address (e.g., 192.168.1.7/24 -> 192.168.1.7)
    function _stripCidr(s) {
        if (!s)
            return s;
        try {
            var str = String(s);
            var idx = str.indexOf("/");
            return idx > 0 ? str.substring(0, idx) : str;
        } catch (e) {
            return s;
        }
    }

    function _isConnected(state) {
        return state && state.indexOf("connected") !== -1;
    }

    // Pick first wifi iface from devices
    function _firstWifiInterface() {
        if (!net.devices)
            return "";
        for (var i = 0; i < net.devices.length; i++)
            if (net.devices[i].type === "wifi")
                return net.devices[i].interface || "";
        return "";
    }

    // Recompute simplified/derived state from devices
    function _updateDerivedState() {
        var wifiIf = "";
        var ethIf = "";
        var wifiConn = false;
        var ethConn = false;
        var wifiIp = "";
        var ethIp = "";
        for (var i = 0; i < net.devices.length; i++) {
            var d = net.devices[i];
            var isConnected = net._isConnected(d.state);
            if (d.type === "wifi") {
                wifiIf = d.interface || wifiIf;
                wifiConn = wifiConn || isConnected;
                if (d.ip4)
                    wifiIp = net._stripCidr(d.ip4);
            } else if (d.type === "ethernet") {
                ethIf = d.interface || ethIf;
                ethConn = ethConn || isConnected;
                if (d.ip4)
                    ethIp = net._stripCidr(d.ip4);
            }
        }
        var prevStatus = net.networkStatus;
        net.wifiInterface = wifiIf;
        net.wifiConnected = wifiConn;
        net.wifiIP = wifiIp;
        net.ethernetInterface = ethIf;
        net.ethernetConnected = ethConn;
        net.ethernetIP = ethIp;
        if (wifiConn)
            net.networkStatus = "wifi";
        else if (ethConn)
            net.networkStatus = "ethernet";
        else
            net.networkStatus = "disconnected";
        if (prevStatus !== net.networkStatus)
            net.connectionChanged();
    }

    // Parse nmcli multiline device output into array of device objects
    function _parseDeviceListMultiline(text) {
        var out = [];
        var lines = text.split(/\n+/);
        var obj = {
            interface: ""
        };
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line)
                continue;
            var idx = line.indexOf(":");
            if (idx <= 0)
                continue;
            var key = line.substring(0, idx).trim();
            var val = line.substring(idx + 1).trim();

            // If we hit a DEVICE key, start a new object and push previous
            if (key === "GENERAL.DEVICE" || key === "DEVICE") {
                if (obj.interface)
                    out.push(obj);
                obj = {
                    interface: val,
                    type: "",
                    state: "",
                    name: "",
                    mac: "",
                    ip4: null,
                    ip6: null,
                    connectionId: null
                };
                continue;
            }
            if (!obj)
                continue; // skip until we have a device

            if (key === "GENERAL.TYPE" || key === "TYPE")
                obj.type = val;
            else if (key === "GENERAL.STATE" || key === "STATE")
                obj.state = val;
            else if (key === "GENERAL.CONNECTION" || key === "CONNECTION" || key === "GENERAL.CON-UUID" || key === "CON-UUID")
                obj.connectionId = val;
            else if (key === "GENERAL.HWADDR" || key === "HWADDR")
                obj.mac = val;
            else if (key.indexOf("IP4.ADDRESS") === 0 || key === "IP4.ADDRESS")
                obj.ip4 = val;
            else if (key.indexOf("IP6.ADDRESS") === 0 || key === "IP6.ADDRESS")
                obj.ip6 = val;
        }
        if (obj.interface)
            out.push(obj);
        return out;
    }

    // Parse nmcli multiline wifi listing
    function _newWifiEntry() {
        return {
            ssid: "",
            bssid: "",
            signal: 0,
            security: "",
            freq: "",
            connected: false,
            seenAt: net._nowMs()
        };
    }

    function _parseWifiListMultiline(text) {
        var out = [];
        var lines = (text || "").split(/\n+/);
        var obj = null;
        function pushIfValid(o) {
            if (!o)
                return;
            if ((o.ssid && o.ssid.length > 0) || (o.bssid && o.bssid.length > 0))
                out.push(o);
        }
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (!line || line.trim().length === 0)
                continue;
            var idx = line.indexOf(":");
            if (idx <= 0)
                continue;
            var key = line.substring(0, idx).trim();
            var val = line.substring(idx + 1).trim();

            if (key === "IN-USE" || key === "SSID") {
                if (obj)
                    pushIfValid(obj);
                obj = net._newWifiEntry();
            }
            if (!obj)
                obj = net._newWifiEntry();

            if (key === "SSID")
                obj.ssid = val;
            else if (key === "BSSID")
                obj.bssid = val;
            else if (key === "SIGNAL")
                obj.signal = parseInt(val) || 0;
            else if (key === "SECURITY")
                obj.security = val;
            else if (key === "FREQ")
                obj.freq = val;
            else if (key === "IN-USE")
                obj.connected = (val === "*");
        }
        pushIfValid(obj);
        return out;
    }

    // Choose active device with priority
    function _chooseActiveDevice(devs) {
        if (!devs || devs.length === 0)
            return null;
        var wifi = null, eth = null, other = null, loop = null;
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i];
            if (!net._isConnected(d.state)) {
                if (d.type === "loopback")
                    loop = d;
                continue;
            }
            if (d.type === "wifi" && !wifi)
                wifi = d;
            else if (d.type === "ethernet" && !eth)
                eth = d;
            else if (d.type !== "loopback" && !other)
                other = d;
            else if (d.type === "loopback" && !loop)
                loop = d;
        }
        return wifi || eth || other || (function () {
                var hasNonLoop = false;
                for (var j = 0; j < devs.length; j++)
                    if (devs[j].type !== "loopback") {
                        hasNonLoop = true;
                        break;
                    }
                return hasNonLoop ? null : loop;
            })();
    }

    // Merge device details into devices list by interface
    function _mergeDeviceDetails(iface, details) {
        for (var i = 0; i < net.devices.length; i++) {
            if (net.devices[i].interface === iface) {
                for (var k in details)
                    net.devices[i][k] = details[k];
                net.devicesChanged();
                return;
            }
        }
        var obj = {
            interface: iface
        };
        for (var k2 in details)
            obj[k2] = details[k2];
        net.devices.push(obj);
        net.devicesChanged();
    }

    // Tag wifiNetworks entries with saved/connected flags
    function _applySavedFlags() {
        if (!net.wifiNetworks)
            return;
        var savedSet = {};
        if (net.savedConnections)
            for (var i = 0; i < net.savedConnections.length; i++)
                savedSet[net.savedConnections[i].ssid] = true;
        // Prefer active SSID derived from the latest scan (IN-USE field)
        var activeSsid = null;
        try {
            for (var a = 0; a < net.wifiNetworks.length; a++) {
                var cand = net.wifiNetworks[a];
                if (cand && cand.connected && cand.ssid) {
                    activeSsid = cand.ssid;
                    break;
                }
            }
            // Fallback: derive from activeDevice only if scan didn't mark any network as connected
            if (!activeSsid && net.activeDevice && net.activeDevice.type === "wifi")
                activeSsid = (net.activeDevice.name || "");
        } catch (e) {}
        for (var j = 0; j < net.wifiNetworks.length; j++) {
            var wn = net.wifiNetworks[j];
            wn.saved = !!savedSet[wn.ssid];
            // Only set connected based on fallback when scan did not mark any connected network
            if (activeSsid && !wn.connected)
                wn.connected = (wn.ssid === activeSsid);
        }
        net.wifiNetworksChanged();
    }

    // Request device details (dynamic Process)
    function _requestDeviceDetails(iface) {
        try {
            var qml = 'import Quickshell.Io; Process { id: p; stdout: StdioCollector { onStreamFinished: function() { /* placeholder */ } } }';
            var obj = Qt.createQmlObject(qml, net, "dynamicProc_");
            if (!obj) {
                net._setError("Failed to create dynamic process object");
                return;
            }
            obj.command = ["nmcli", "-m", "multiline", "-f", "ALL", "device", "show", iface];
            try {
                obj.stdout.streamFinished.connect(function () {
                    try {
                        var textOut = obj.stdout.text || "";
                        var map = {};
                        var lines = textOut.trim().split(/\n+/);
                        for (var i = 0; i < lines.length; i++) {
                            var line = lines[i];
                            var idx = line.indexOf(":");
                            if (idx > 0) {
                                var key = line.substring(0, idx).trim();
                                var val = line.substring(idx + 1).trim();
                                map[key] = val;
                            }
                        }
                        var ifc = map["GENERAL.DEVICE"] || map["DEVICE"] || iface;
                        var details = {
                            mac: map["GENERAL.HWADDR"] || map["HWADDR"] || "",
                            type: map["GENERAL.TYPE"] || map["TYPE"] || "",
                            name: map["GENERAL.CONNECTION"] || map["CONNECTION"] || map["GENERAL.CON-UUID"] || map["CON-UUID"] || map["GENERAL.TYPE"] || ifc,
                            ip4: net._stripCidr(map["IP4.ADDRESS[1]"] || map["IP4.ADDRESS"] || null),
                            ip6: map["IP6.ADDRESS[1]"] || map["IP6.ADDRESS"] || null,
                            connectionId: map["GENERAL.CONNECTION"] || map["CONNECTION"] || map["GENERAL.CON-UUID"] || map["CON-UUID"] || null
                        };
                        net._mergeDeviceDetails(ifc, details);
                        try {
                            if ((map["GENERAL.TYPE"] || map["TYPE"]) === "wifi") {
                                net.wifiInterface = ifc;
                                net.wifiIP = net._stripCidr(details.ip4 || net.wifiIP);
                            } else if ((map["GENERAL.TYPE"] || map["TYPE"]) === "ethernet") {
                                net.ethernetInterface = ifc;
                                net.ethernetIP = net._stripCidr(details.ip4 || net.ethernetIP);
                            }
                            net._updateDerivedState();
                        } catch (e) {}
                        net._log("[NetworkService] Merged device details for", ifc, "-> mac=", details.mac, "conn=", details.connectionId, "ip4=", details.ip4);
                    } catch (ex) {
                        net._setError("Failed parsing dynamic device show output: " + ex);
                    }
                    try {
                        obj.destroy();
                    } catch (ee) {}
                });
            } catch (connErr) {
                net._setError("Unable to attach streamFinished handler: " + connErr);
                try {
                    obj.destroy();
                } catch (ee) {}
            }
            obj.running = true;
        } catch (e) {
            net._setError("Unable to request device details: " + e);
        }
    }

    // === Public API ===
    // Run nmcli scan for wifi
    function refreshWifiScan(iface) {
        net._log("[NetworkService] refreshWifiScan(iface=", iface, ")");
        var now = net._nowMs();
        if (net.scanning)
            return;
        if (!net.wifiRadioEnabled) {
            net._log("[NetworkService] wifi radio disabled; skip scan");
            net.wifiNetworks = [];
            net.wifiNetworksChanged();
            net.networksUpdated();
            return;
        }
        try {
            for (var di = 0; di < net.devices.length; di++) {
                var d = net.devices[di];
                if (d.interface === iface && d.state && d.state.indexOf("unavailable") !== -1) {
                    net._log("[NetworkService] wifi device unavailable; skip scan");
                    net.wifiNetworks = [];
                    net.wifiNetworksChanged();
                    net.networksUpdated();
                    return;
                }
            }
        } catch (e) {}
        if (now - net.lastWifiScanAt < net.wifiScanCooldownMs) {
            net._log("[NetworkService] wifi scan cooldown active");
            return;
        }
        net.scanning = true;
        net.scanningChanged();
        try {
            procWifiList.command = ["nmcli", "-m", "multiline", "-f", "IN-USE,SSID,BSSID,SIGNAL,SECURITY,FREQ", "device", "wifi", "list", "ifname", iface];
            procWifiList.running = true;
        } catch (e) {
            net._setError("Unable to run wifi scan");
            net.scanning = false;
            net.scanningChanged();
        }
    }
    function refreshDevices() {
        net._log("[NetworkService] refreshDevices()");
        var now = net._nowMs();
        if (now - net.lastDevicesRefreshAt < net.deviceRefreshCooldownMs) {
            net._log("[NetworkService] device refresh cooldown active");
            return;
        }
        net.lastDevicesRefreshAt = now;
        try {
            procListDevices.running = true;
        } catch (e) {
            net._setError("Unable to run device list: " + e);
        }
    }

    // One-shot: refresh devices and, if wifi present, wifi networks
    function refresh() {
        // clear transient error state on manual/monitor refresh
        net.lastError = "";
        net.refreshDevices();
        var iface = net._firstWifiInterface();
        if (iface && net.wifiRadioEnabled)
            net.refreshWifiScan(iface);
        // avoid running saved-connections every refresh; run on init and after changes
        try {
            procWifiRadio.running = true;
        } catch (e2) {}
    }

    // Convenience: refresh wifi without passing iface
    function refreshWifi() {
        var iface = net._firstWifiInterface();
        if (iface)
            net.refreshWifiScan(iface);
    }

    function connectWifi(ssid, password, iface, save = false, name) {
        net._log("[NetworkService] connectWifi(ssid=", ssid, ", iface=", iface, ", save=", save, ")");
        try {
            if (!iface || iface === "")
                iface = net._firstWifiInterface();
            if (save && name) {
                net._log("[NetworkService] adding connection con-name=", name, "ssid=", ssid);
                net._runProcConnect(["nmcli", "connection", "add", "type", "wifi", "ifname", iface, "con-name", name, "ssid", ssid]);
                return;
            }
            if (password)
                net._runProcConnect(["nmcli", "device", "wifi", "connect", ssid, "password", password, "ifname", iface]);
            else
                net._runProcConnect(["nmcli", "device", "wifi", "connect", ssid, "ifname", iface]);
        } catch (e) {
            net._setError("Unable to start connect command: " + e);
        }
    }

    function activateConnection(connId, iface) {
        net._log("[NetworkService] activateConnection(connId=", connId, ", iface=", iface, ")");
        try {
            net._runProcConnect(["nmcli", "connection", "up", "id", connId, "ifname", iface]);
        } catch (e) {
            net._setError("Unable to activate connection: " + e);
        }
    }

    function disconnect(iface) {
        net._log("[NetworkService] disconnect(iface=", iface, ")");
        try {
            net._runProcConnect(["nmcli", "device", "disconnect", iface]);
        } catch (e) {
            net._setError("Unable to disconnect device");
        }
    }

    // Convenience: disconnect currently active wifi device
    function disconnectWifi() {
        var iface = net._firstWifiInterface();
        if (iface)
            net.disconnect(iface);
    }

    // Forget a saved Wi-Fi connection by SSID (connection id/name)
    function forgetWifi(ssid) {
        try {
            procForget.command = ["nmcli", "connection", "delete", ssid];
            procForget.running = true;
        } catch (e) {
            net._setError("Unable to start forget command");
        }
    }

    function dumpState() {
        try {
            net._log("[NetworkService] DUMP STATE: devices=", JSON.stringify(net.devices));
        } catch (e) {
            net._log("[NetworkService] dumpState devices stringify failed:", e);
        }
        try {
            net._log("[NetworkService] DUMP STATE: wifiNetworks=", JSON.stringify(net.wifiNetworks));
        } catch (e) {
            net._log("[NetworkService] dumpState wifi stringify failed:", e);
        }
    }

    // Public API: set and toggle Wi‑Fi radio
    function setWifiRadio(enabled) {
        try {
            var arg = enabled ? "on" : "off";
            net._runProcConnect(["nmcli", "radio", "wifi", arg]);
        } catch (e) {
            net._setError("Unable to toggle Wi‑Fi radio: " + e);
        }
    }

    function toggleWifiRadio() {
        net.setWifiRadio(!net.wifiRadioEnabled);
    }

    // === Timers ===
    // Debounce timer for monitor-driven refreshes
    Timer {
        id: monitorDebounce
        interval: 500
        repeat: false
        running: false
        onTriggered: {
            net.refresh();
        }
    }

    // Polling fallback timers
    Timer {
        id: devicePollTimer
        interval: net.devicePollIntervalMs
        repeat: true
        running: net.usePollingFallback
        onTriggered: net.refreshDevices
    }

    Timer {
        id: wifiPollTimer
        interval: net.wifiPollIntervalMs
        repeat: true
        running: net.usePollingFallback
        onTriggered: {
            if (net.devices && net.devices.length > 0) {
                var iface = null;
                for (var i = 0; i < net.devices.length; i++)
                    if (net.devices[i].type === "wifi") {
                        iface = net.devices[i].interface;
                        break;
                    }
                if (iface)
                    net.refreshWifiScan(iface);
            }
        }
    }

    // === Processes ===
    // Long-running monitor: nmcli monitor
    Process {
        id: monitorProc
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                if (monitorDebounce.running)
                    monitorDebounce.stop();
                monitorDebounce.start();
            }
        }
        Component.onCompleted: {
            try {
                net._log("[NetworkService] Starting nmcli monitor");
                monitorProc.running = true;
                net.monitorRunning = true;
            } catch (e) {
                net.monitorRunning = false;
                net.usePollingFallback = true;
                net._log("[NetworkService] Failed to start monitor:", e);
            }
        }
        onRunningChanged: function () {
            if (!running) {
                net.monitorRunning = false;
                net.usePollingFallback = true;
                net._log("[NetworkService] nmcli monitor stopped");
            }
        }
    }

    // Query Wi‑Fi radio state
    Process {
        id: procWifiRadio
        command: ["nmcli", "-t", "-f", "WIFI", "general"]
        stdout: StdioCollector {
            onStreamFinished: function () {
                try {
                    var v = (text || "").trim().toLowerCase();
                    var enabled = (v.indexOf("enabled") !== -1 || v === "yes" || v === "on");
                    if (net.wifiRadioEnabled !== enabled) {
                        net.wifiRadioEnabled = enabled;
                        net.wifiRadioChanged();
                    }
                } catch (e) {}
            }
        }
    }

    // List network devices
    Process {
        id: procListDevices
        command: ["nmcli", "-m", "multiline", "-f", "DEVICE,TYPE,STATE,CONNECTION,CON-UUID", "device"]
        stdout: StdioCollector {
            onStreamFinished: function () {
                try {
                    var parsed = net._parseDeviceListMultiline(text);
                    net.devices = parsed;
                    net._updateDerivedState();
                    var devSummary = "devices=" + net.devices.length + ": ";
                    for (var d = 0; d < net.devices.length; d++) {
                        var dv = net.devices[d];
                        devSummary += dv.interface + "(" + dv.type + "," + dv.state + ") ";
                    }
                    net._log("[NetworkService] Parsed devices:", devSummary);
                    for (var i = 0; i < net.devices.length; i++) {
                        var dv = net.devices[i];
                        if (dv.type === "loopback" || dv.type === "wifi-p2p")
                            continue;
                        net._requestDeviceDetails(dv.interface);
                    }
                    var chosen = net._chooseActiveDevice(net.devices);
                    if (chosen) {
                        net.activeDevice = chosen;
                        net._log("[NetworkService] Active device:", net.activeDevice.interface, "type=", net.activeDevice.type, "state=", net.activeDevice.state, "connection=", net.activeDevice.connectionId, "ip4=", net.activeDevice.ip4);
                    }
                    // clear last error on successful parse
                    net.lastError = "";
                } catch (e) {
                    net._setError("Failed parsing device list: " + e);
                }
            }
        }
    }

    // Wi‑Fi list results
    Process {
        id: procWifiList
        stdout: StdioCollector {
            onStreamFinished: function () {
                try {
                    var parsed = net._parseWifiListMultiline(text);
                    net.wifiNetworks = parsed;
                    net._applySavedFlags();
                    var ncount = net.wifiNetworks ? net.wifiNetworks.length : 0;
                    var top = [];
                    for (var k = 0; k < Math.min(5, ncount); k++)
                        top.push(net.wifiNetworks[k].ssid + "(" + net.wifiNetworks[k].signal + ")");
                    net._log("[NetworkService] Wifi scan results: count=", ncount, " top=", top.join(", "));
                    if (net.activeDevice && net.activeDevice.type === "wifi" && ncount > 0 && net._isConnected(net.activeDevice.state))
                        net._log("[NetworkService] Active wifi device:", net.activeDevice.interface, "connection=", net.activeDevice.connectionId);
                    net.networksUpdated();
                } catch (e) {
                    net._setError("Failed parsing wifi list: " + e);
                }
                net.scanning = false;
                net.scanningChanged();
                net.lastWifiScanAt = net._nowMs();
            }
        }
    }

    // Connect / generic executor
    Process {
        id: procConnect
        stdout: StdioCollector {
            onStreamFinished: function () {
                net._log("[NetworkService] Connect finished");
                net.refreshDevices();
                // saved connections may have changed
                try {
                    procSaved.running = true;
                } catch (e) {}
            }
        }
    }

    // Fetch saved connections
    Process {
        id: procSaved
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: function () {
                try {
                    var list = [];
                    var lines = text.trim().split(/\n+/);
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim();
                        if (!line)
                            continue;
                        var parts = line.split(":");
                        if (parts.length >= 2 && parts[1] === "802-11-wireless")
                            list.push({
                                ssid: parts[0]
                            });
                    }
                    net.savedConnections = list;
                    net._applySavedFlags();
                } catch (e) {
                    net._setError("Failed parsing saved connections list");
                }
            }
        }
    }

    // Forget a saved Wi‑Fi connection
    Process {
        id: procForget
        stdout: StdioCollector {
            onStreamFinished: function () {
                net._log("[NetworkService] Forget finished");
                net.refresh();
                // update saved list after deletion
                try {
                    procSaved.running = true;
                } catch (e) {}
            }
        }
    }

    // === Lifecycle ===
    Component.onCompleted: {
        net._log("[NetworkService] Component.onCompleted - initializing, setting ready=true");
        net.ready = true;
        net.refreshDevices();
        try {
            procSaved.running = true;
        } catch (e) {}
        try {
            procWifiRadio.running = true;
        } catch (e2) {}
    }
}
