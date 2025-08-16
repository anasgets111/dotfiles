pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: net

    // readiness
    property bool ready: false

    // backend info
    property string backend: "nmcli"

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

    // scanning / monitor state
    property bool scanning: false
    property int lastWifiScanAt: 0
    property int wifiScanCooldownMs: 10000

    // polling fallback settings
    property bool monitorRunning: false
    property bool usePollingFallback: false
    property int devicePollIntervalMs: 5000
    property int wifiPollIntervalMs: 30000

    property string lastError: ""

    // property change signals are auto-provided by QML
    signal error(string message)
    signal networksUpdated
    signal connectionChanged

    // --- Helpers ---
    function _nowMs() {
        return Date.now();
    }

    function _setError(msg) {
        net.lastError = msg;
        net.error(msg);
        console.log("[NetworkService] Error:", msg);
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
            var isConnected = (d.state && d.state.indexOf("connected") !== -1);
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

    // (terse parsers removed as unused)

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

    // Parse nmcli multiline wifi listing: fields like SSID:, BSSID:, SIGNAL:, SECURITY:, FREQ:, IN-USE:
    function _parseWifiListMultiline(text) {
        var out = [];
        var blocks = text.split(/\n\s*\n/);
        for (var b = 0; b < blocks.length; b++) {
            var block = blocks[b].trim();
            if (!block)
                continue;
            var lines = block.split(/\n+/);
            var obj = {
                ssid: "",
                bssid: "",
                signal: 0,
                security: "",
                freq: "",
                connected: false,
                seenAt: net._nowMs()
            };
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i];
                var idx = line.indexOf(":");
                if (idx <= 0)
                    continue;
                var key = line.substring(0, idx).trim();
                var val = line.substring(idx + 1).trim();
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
            out.push(obj);
        }
        return out;
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
        // not found, add
        var obj = {
            interface: iface
        };
        for (var k2 in details)
            obj[k2] = details[k2];
        net.devices.push(obj);
        net.devicesChanged();
    }

    // --- Processes ---
    // Long-running monitor: nmcli monitor
    Process {
        id: monitorProc
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                // debounce refresh on monitor changes
                try {
                    if (monitorDebounce.running) {
                        monitorDebounce.stop();
                    }
                    monitorDebounce.start();
                } catch (e) {}
            }
        }
        Component.onCompleted: {
            // start monitor
            try {
                console.log("[NetworkService] Starting nmcli monitor");
                monitorProc.running = true;
                net.monitorRunning = true;
            } catch (e) {
                net.monitorRunning = false;
                net.usePollingFallback = true;
                console.log("[NetworkService] Failed to start monitor:", e);
            }
        }
        onExited: function (exitCode) {
            net.monitorRunning = false;
            net.usePollingFallback = true;
            console.log("[NetworkService] nmcli monitor exited code=", exitCode);
        }
    }

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

    // One-off processes
    Process {
        id: procListDevices
        // use multiline mode for robust parsing
        command: ["nmcli", "-m", "multiline", "-f", "DEVICE,TYPE,STATE,CONNECTION,CON-UUID,DBUS-PATH", "device"]
        stdout: StdioCollector {
            onStreamFinished: function () {
                try {
                    console.log("[NetworkService] Device list (multiline) stdout:\n", text);
                    var parsed = net._parseDeviceListMultiline(text);
                    net.devices = parsed;
                    net._updateDerivedState();
                    // log parsed devices summary
                    try {
                        var devSummary = "devices=" + net.devices.length + ": ";
                        for (var d = 0; d < net.devices.length; d++) {
                            var dv = net.devices[d];
                            devSummary += dv.interface + "(" + dv.type + "," + dv.state + ") ";
                        }
                        console.log("[NetworkService] Parsed devices:", devSummary);
                    } catch (e) {
                        console.log("[NetworkService] Failed to log devices summary:", e);
                    }
                    net.devicesChanged();
                    // fetch details for each device (async fire-and-forget) - device show still used for full info
                    for (var i = 0; i < net.devices.length; i++) {
                        net._requestDeviceDetails(net.devices[i].interface);
                    }
                    // set activeDevice if any connected
                    for (var j = 0; j < net.devices.length; j++) {
                        if (net.devices[j].state && net.devices[j].state.indexOf("connected") !== -1) {
                            net.activeDevice = net.devices[j];
                            net.activeDeviceChanged();
                            try {
                                console.log("[NetworkService] Active device:", net.activeDevice.interface, "type=", net.activeDevice.type, "state=", net.activeDevice.state, "connection=", net.activeDevice.connectionId, "ip4=", net.activeDevice.ip4);
                            } catch (e) {
                                console.log("[NetworkService] Failed to log activeDevice:", e);
                            }
                            break;
                        }
                    }
                } catch (e) {
                    net._setError("Failed parsing device list: " + e);
                }
            }
        }
    }

    // One-off wifi listing
    Process {
        id: procWifiList
        // set command before running
        stdout: StdioCollector {
            onStreamFinished: function () {
                try {
                    console.log("[NetworkService] Wifi list (multiline) stdout:\n", text);
                    var parsed = net._parseWifiListMultiline(text);
                    net.wifiNetworks = parsed;
                    net.wifiNetworksChanged();
                    // merge saved flags if available
                    net._applySavedFlags();
                    try {
                        var ncount = net.wifiNetworks ? net.wifiNetworks.length : 0;
                        var top = [];
                        for (var k = 0; k < Math.min(5, ncount); k++)
                            top.push(net.wifiNetworks[k].ssid + "(" + net.wifiNetworks[k].signal + ")");
                        console.log("[NetworkService] Wifi scan results: count=", ncount, " top=", top.join(", "));
                        if (net.activeDevice && net.activeDevice.type === "wifi") {
                            console.log("[NetworkService] Active wifi device:", net.activeDevice.interface, "connection=", net.activeDevice.connectionId);
                        }
                    } catch (e) {
                        console.log("[NetworkService] Failed to log wifi networks:", e);
                    }
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

    // One-off connect
    Process {
        id: procConnect
        // set command before running
        stdout: StdioCollector {
            onStreamFinished: function () {
                // after connecting, refresh devices and connections
                console.log("[NetworkService] Connect stdout:\n", text);
                net.refreshDevices();
            }
        }
    }

    // --- Public API ---
    function refreshDevices() {
        console.log("[NetworkService] refreshDevices()");
        try {
            procListDevices.running = true;
        } catch (e) {
            net._setError("Unable to run device list: " + e);
        }
    }

    // One-shot: refresh devices and, if wifi present, wifi networks
    function refresh() {
        net.refreshDevices();
        var iface = net._firstWifiInterface();
        if (iface)
            net.refreshWifiScan(iface);
        try {
            procSaved.running = true;
        } catch (e) {}
    }

    function _requestDeviceDetails(iface) {
        try {
            // create a per-request Process + StdioCollector so concurrent requests don't clobber each other
            var qml = 'import Quickshell.Io; Process { id: p; stdout: StdioCollector { onStreamFinished: function() { /* placeholder */ } } }';
            var obj = Qt.createQmlObject(qml, net, "dynamicProc_");
            if (!obj) {
                net._setError("Failed to create dynamic process object");
                return;
            }
            // set the command
            obj.command = ["nmcli", "-m", "multiline", "-f", "ALL", "device", "show", iface];
            // wire the stdout handler to parse and merge details using the streamFinished signal
            try {
                obj.stdout.streamFinished.connect(function () {
                    try {
                        var textOut = obj.stdout.text || "";
                        console.log("[NetworkService] Device show stdout (dynamic):\n", textOut);
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
                            // prefer explicit HWADDR keys, fallback to short key
                            mac: map["GENERAL.HWADDR"] || map["HWADDR"] || "",
                            // normalize type and name: type from GENERAL.TYPE, name prefer connection id/name
                            type: map["GENERAL.TYPE"] || map["TYPE"] || "",
                            name: map["GENERAL.CONNECTION"] || map["CONNECTION"] || map["GENERAL.CON-UUID"] || map["CON-UUID"] || map["GENERAL.TYPE"] || ifc,
                            ip4: net._stripCidr(map["IP4.ADDRESS[1]"] || map["IP4.ADDRESS"] || null),
                            ip6: map["IP6.ADDRESS[1]"] || map["IP6.ADDRESS"] || null,
                            connectionId: map["GENERAL.CONNECTION"] || map["CONNECTION"] || map["GENERAL.CON-UUID"] || map["CON-UUID"] || null
                        };
                        net._mergeDeviceDetails(ifc, details);
                        // also update simplified state with IPs if known
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
                        try {
                            console.log("[NetworkService] Merged device details for", ifc, "-> mac=", details.mac, "conn=", details.connectionId, "ip4=", details.ip4);
                        } catch (e) {
                            console.log("[NetworkService] Failed to log merged details:", e);
                        }
                    } catch (ex) {
                        net._setError("Failed parsing dynamic device show output: " + ex);
                    }
                    // cleanup the dynamic object
                    try {
                        obj.destroy();
                    } catch (ee) {}
                });
            } catch (connErr) {
                // fallback if connect is not available
                net._setError("Unable to attach streamFinished handler: " + connErr);
                try {
                    obj.destroy();
                } catch (ee) {}
            }
            // start it
            obj.running = true;
        } catch (e) {
            net._setError("Unable to request device details: " + e);
        }
    }

    function refreshWifiScan(iface) {
        console.log("[NetworkService] refreshWifiScan(iface=", iface, ")");
        var now = net._nowMs();
        if (net.scanning)
            return;
        if (now - net.lastWifiScanAt < net.wifiScanCooldownMs) {
            console.log("[NetworkService] wifi scan cooldown active");
            return;
        }
        net.scanning = true;
        net.scanningChanged();
        try {
            // run list directly - nmcli handles scanning
            procWifiList.command = ["nmcli", "-m", "multiline", "-f", "IN-USE,SSID,BSSID,SIGNAL,SECURITY,FREQ", "device", "wifi", "list", "ifname", iface];
            procWifiList.running = true;
        } catch (e) {
            net._setError("Unable to run wifi scan");
            net.scanning = false;
            net.scanningChanged();
        }
    }

    // Convenience: refresh wifi without passing iface
    function refreshWifi() {
        var iface = net._firstWifiInterface();
        if (iface)
            net.refreshWifiScan(iface);
    }

    function connectWifi(ssid, password, iface, save = false, name) {
        console.log("[NetworkService] connectWifi(ssid=", ssid, ", iface=", iface, ", save=", save, ")");
        // If save true and name provided, attempt to add connection
        try {
            if (!iface || iface === "")
                iface = net._firstWifiInterface();
            if (save && name) {
                console.log("[NetworkService] adding connection con-name=", name, "ssid=", ssid);
                procConnect.command = ["nmcli", "connection", "add", "type", "wifi", "ifname", iface, "con-name", name, "ssid", ssid];
                procConnect.running = true;
                // then modify security
                // Note: nmcli commands could be chained but we keep them simple; caller can call activateConnection after add
                return;
            }
            if (password) {
                procConnect.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password, "ifname", iface];
            } else {
                procConnect.command = ["nmcli", "device", "wifi", "connect", ssid, "ifname", iface];
            }
            procConnect.running = true;
        } catch (e) {
            net._setError("Unable to start connect command: " + e);
        }
    }

    function activateConnection(connId, iface) {
        console.log("[NetworkService] activateConnection(connId=", connId, ", iface=", iface, ")");
        try {
            procConnect.command = ["nmcli", "connection", "up", "id", connId, "ifname", iface];
            procConnect.running = true;
        } catch (e) {
            net._setError("Unable to activate connection: " + e);
        }
    }

    function disconnect(iface) {
        console.log("[NetworkService] disconnect(iface=", iface, ")");
        try {
            procConnect.command = ["nmcli", "device", "disconnect", iface];
            procConnect.running = true;
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
            console.log("[NetworkService] DUMP STATE: devices=", JSON.stringify(net.devices));
        } catch (e) {
            console.log("[NetworkService] dumpState devices stringify failed:", e);
        }
        try {
            console.log("[NetworkService] DUMP STATE: wifiNetworks=", JSON.stringify(net.wifiNetworks));
        } catch (e) {
            console.log("[NetworkService] dumpState wifi stringify failed:", e);
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
            // choose first wifi device if available
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

    // Saved connections fetcher and forgetter
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

    Process {
        id: procForget
        stdout: StdioCollector {
            onStreamFinished: function () {
                console.log("[NetworkService] Forget result:\n", text);
                net.refresh();
            }
        }
    }

    Component.onCompleted: {
        console.log("[NetworkService] Component.onCompleted - initializing, setting ready=true");
        net.ready = true;
        // initial refresh
        net.refreshDevices();
        try {
            procSaved.running = true;
        } catch (e) {}
    }

    function _applySavedFlags() {
        if (!net.wifiNetworks)
            return;
        var savedSet = {};
        if (net.savedConnections) {
            for (var i = 0; i < net.savedConnections.length; i++)
                savedSet[net.savedConnections[i].ssid] = true;
        }
        var activeSsid = null;
        try {
            if (net.activeDevice && net.activeDevice.type === "wifi")
                activeSsid = net.activeDevice && (net.activeDevice.name || "");
        } catch (e) {}
        for (var j = 0; j < net.wifiNetworks.length; j++) {
            var wn = net.wifiNetworks[j];
            wn.saved = !!savedSet[wn.ssid];
            if (activeSsid)
                wn.connected = (wn.ssid === activeSsid);
        }
        net.wifiNetworksChanged();
    }
}
