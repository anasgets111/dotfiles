pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils
import qs.Services.SystemInfo

Singleton {
    id: net
    // === Config constants (tunable defaults) ===
    readonly property int defaultBootSuppressMs: 8000
    readonly property int defaultNotifyDebounceMs: 4000
    readonly property int defaultWifiScanCooldownMs: 10000
    readonly property int defaultDeviceRefreshCooldownMs: 1000
    readonly property int defaultDevicePollMs: 5000
    readonly property int defaultWifiPollMs: 30000
    readonly property int suppressDisconnectMs: 15000
    readonly property int suppressWifiSwitchMs: 20000

    // === Properties ===
    // readiness
    property bool ready: false

    // debug logging (set true to see verbose logs)
    // In-shell toast/OSD and Notifications (instantiated via properties)
    readonly property var osd: OSDService
    readonly property var notifs: NotificationService

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
    property int wifiScanCooldownMs: defaultWifiScanCooldownMs
    // device refresh cooldown
    property int lastDevicesRefreshAt: 0
    property int deviceRefreshCooldownMs: defaultDeviceRefreshCooldownMs

    // polling fallback settings
    property bool usePollingFallback: false
    property int devicePollIntervalMs: defaultDevicePollMs
    property int wifiPollIntervalMs: defaultWifiPollMs

    property string lastError: ""

    // --- Notification & suppression helpers ---
    // Track last-known connectivity to detect transitions
    property bool _lastWifiConnected: false
    property bool _lastEthernetConnected: false
    // Boot suppression to avoid startup spam (ms)
    property int _bootSuppressMs: defaultBootSuppressMs
    property double _bootStartedAt: 0
    // Suppress windows for user-initiated actions (epoch ms per type/iface)
    property double _wifiSuppressUntil: 0
    property double _ethSuppressUntil: 0
    property var _ifaceSuppressUntil: ({})
    // Simple debounce to avoid repeated toasts (ms)
    property int _notifyDebounceMs: defaultNotifyDebounceMs
    property double _lastNotifyAt: 0

    // === Signals ===
    // property change signals are auto-provided by QML
    signal error(string message)
    signal connectionChanged
    signal wifiRadioChanged

    // === Internal helpers ===
    function _nowMs() {
        return Date.now();
    }

    // Cooldown helpers
    function _cooldownActive(lastAt, cooldownMs, now) {
        var n = now !== undefined ? now : net._nowMs();
        return (n - lastAt) < cooldownMs;
    }

    // Derived-state computation (pure)
    function _computeDerived(devs) {
        var wifiIf = "", ethIf = "";
        var wifiConn = false, ethConn = false;
        var wifiIp = "", ethIp = "";
        var wifiName = "", ethName = "";
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i];
            var isConnected = net._isConnected(d.state);
            if (d.type === "wifi") {
                wifiIf = d.interface || wifiIf;
                wifiConn = wifiConn || isConnected;
                if (d.ip4)
                    wifiIp = net._stripCidr(d.ip4);
                if (isConnected && d.connectionName)
                    wifiName = d.connectionName;
            } else if (d.type === "ethernet") {
                ethIf = d.interface || ethIf;
                ethConn = ethConn || isConnected;
                if (d.ip4)
                    ethIp = net._stripCidr(d.ip4);
                if (isConnected && d.connectionName)
                    ethName = d.connectionName;
            }
        }
        var status = wifiConn ? "wifi" : (ethConn ? "ethernet" : "disconnected");
        return {
            wifiIf: wifiIf,
            ethIf: ethIf,
            wifiConn: wifiConn,
            ethConn: ethConn,
            wifiIp: wifiIp,
            ethIp: ethIp,
            wifiName: wifiName,
            ethName: ethName,
            status: status
        };
    }

    // Centralized runner for procConnect to avoid overlapping runs
    function _runProcConnect(cmdArray) {
        if (procConnect.running) {
            Logger.log("NetworkService", "procConnect busy; skipping command", JSON.stringify(cmdArray));
            return false;
        }
        try {
            procConnect.command = cmdArray;
            procConnect.running = true;
            return true;
        } catch (e) {
            Logger.error("NetworkService", "Unable to start command:", e);
            return false;
        }
    }

    function _setError(msg) {
        net.lastError = msg;
        net.error(msg);
        Logger.error("NetworkService", "Error:", msg);
    }

    // ---- Notify helpers ----
    function _notify(urgency, title, body) {
        var now = net._nowMs();
        if (now - net._lastNotifyAt < net._notifyDebounceMs)
            return;
        net._lastNotifyAt = now;
        // Map urgency to OSD level; default to info to keep behavior lightweight
        var level = 0; // info
        var u = String(urgency || "normal").toLowerCase();
        if (u === "critical")
            level = 2;
        else
        // error
        if (u === "warn" || u === "warning")
            level = 1; // warn
        var t = String(title || "");
        var b = String(body || "");
        var msg = b && b.length > 0 ? (t.length > 0 ? (t + ": " + b) : b) : t;
        try {
            if (net.osd)
                net.osd.showToast(msg, level);
        } catch (e) {
            Logger.warn("NetworkService", "OSD notify failed:", e);
        }
    }

    // Desktop notification via notify-send; used for successful connections
    function _notifyDesktop(urgency, title, body) {
        var now = net._nowMs();
        if (now - net._lastNotifyAt < net._notifyDebounceMs)
            return;
        net._lastNotifyAt = now;
        try {
            notifySendProc.command = ["notify-send", "-u", String(urgency || "normal"), String(title || ""), String(body || "")];
            notifySendProc.running = true;
        } catch (e) {
            Logger.warn("NetworkService", "notify-send failed:", e);
        }
    }

    function _markSuppression(type, iface, ms) {
        var until = net._nowMs() + (ms || 10000);
        if (type === "wifi")
            net._wifiSuppressUntil = Math.max(net._wifiSuppressUntil, until);
        if (type === "ethernet")
            net._ethSuppressUntil = Math.max(net._ethSuppressUntil, until);
        var ifaceStr = String(iface || "");
        if (ifaceStr.length > 0) {
            var m = net._ifaceSuppressUntil;
            m[ifaceStr] = Math.max(m[ifaceStr] || 0, until);
            net._ifaceSuppressUntil = m; // reassign for change notify
        }
    }

    function _isSuppressed(type, iface) {
        var now = net._nowMs();
        if (now - net._bootStartedAt < net._bootSuppressMs)
            return true;
        if (type === "wifi" && now < net._wifiSuppressUntil)
            return true;
        if (type === "ethernet" && now < net._ethSuppressUntil)
            return true;
        if (iface && net._ifaceSuppressUntil && now < (net._ifaceSuppressUntil[iface] || 0))
            return true;
        return false;
    }

    // Trim CIDR suffix from IP address (e.g., 192.168.1.7/24 -> 192.168.1.7)
    function _stripCidr(s) {
        if (!s)
            return s;
        var str = String(s);
        var idx = str.indexOf("/");
        return idx > 0 ? str.substring(0, idx) : str;
    }

    function _isConnected(state) {
        if (!state)
            return false;
        var s = String(state).toLowerCase().trim();
        // Only treat states that START with "connected" as connected.
        // This avoids false positives for "disconnected" and "connecting ...".
        return s.indexOf("connected") === 0;
    }

    // Simple UUID v4 format checker (36 chars, hyphens at 8,13,18,23, hex digits elsewhere)
    function _isUuid(s) {
        var str = String(s);
        if (str.length !== 36)
            return false;
        var hy = {
            8: true,
            13: true,
            18: true,
            23: true
        };
        for (var i = 0; i < 36; i++) {
            var ch = str[i];
            if (hy[i]) {
                if (ch !== '-')
                    return false;
                continue;
            }
            var code = ch.charCodeAt(0);
            var isHex = (code >= 48 && code <= 57) || (code >= 65 && code <= 70) || (code >= 97 && code <= 102);
            if (!isHex)
                return false;
        }
        return true;
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
        var prevStatus = net.networkStatus;
        var prevWifi = net._lastWifiConnected;
        var prevEth = net._lastEthernetConnected;

        var d = net._computeDerived(net.devices || []);
        net.wifiInterface = d.wifiIf;
        net.wifiConnected = d.wifiConn;
        net.wifiIP = d.wifiIp;
        net.ethernetInterface = d.ethIf;
        net.ethernetConnected = d.ethConn;
        net.ethernetIP = d.ethIp;
        net.networkStatus = d.status;
        if (prevStatus !== net.networkStatus)
            net.connectionChanged();

        // Effects: edge notifications
        // Falling edges via OSD
        if (prevWifi && !d.wifiConn && !net._isSuppressed("wifi", d.wifiIf)) {
            var wifiTitle = qsTr("Wi‑Fi disconnected");
            var wifiBody = d.wifiIf ? (qsTr("Interface ") + d.wifiIf) : "";
            net._notify((d.ethConn ? "low" : "normal"), wifiTitle, wifiBody);
        }
        if (prevEth && !d.ethConn && !net._isSuppressed("ethernet", d.ethIf)) {
            var ethTitle = qsTr("Ethernet disconnected");
            var ethBody = d.ethIf ? (qsTr("Interface ") + d.ethIf) : "";
            net._notify((d.wifiConn ? "low" : "normal"), ethTitle, ethBody);
        }

        // Rising edges via desktop notifications (avoid boot spam)
        var bootDelta = net._nowMs() - net._bootStartedAt;
        if (!prevWifi && d.wifiConn && bootDelta >= net._bootSuppressMs) {
            var ssid = d.wifiName && d.wifiName.length ? d.wifiName : d.wifiIf;
            var body = (ssid ? (qsTr("SSID ") + ssid) : "") + (d.wifiIp ? (ssid ? ", IP " : qsTr("IP ")) + d.wifiIp : "");
            net._notifyDesktop("low", qsTr("Wi‑Fi connected"), body);
        }
        if (!prevEth && d.ethConn && bootDelta >= net._bootSuppressMs) {
            var iname = d.ethName && d.ethName.length ? d.ethName : d.ethIf;
            var ebody = (iname ? (qsTr("Interface ") + iname) : "") + (d.ethIp ? (iname ? ", IP " : qsTr("IP ")) + d.ethIp : "");
            net._notifyDesktop("low", qsTr("Ethernet connected"), ebody);
        }

        // Update last-known flags
        net._lastWifiConnected = d.wifiConn;
        net._lastEthernetConnected = d.ethConn;
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
                    mac: "",
                    ip4: null,
                    ip6: null,
                    connectionName: "",
                    connectionUuid: ""
                };
                continue;
            }
            if (!obj)
                continue; // skip until we have a device

            if (key === "GENERAL.TYPE" || key === "TYPE")
                obj.type = val;
            else if (key === "GENERAL.STATE" || key === "STATE")
                obj.state = val;
            else if (key === "GENERAL.CONNECTION" || key === "CONNECTION")
                obj.connectionName = val;
            else if (key === "GENERAL.CON-UUID" || key === "CON-UUID")
                obj.connectionUuid = val;
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
            band: "",
            connected: false
        };
    }

    function _parseWifiListMultiline(text) {
        var out = [];
        var lines = (text || "").split(/\n+/);
        var obj = null;
        function pushIfValid(o) {
            if (!o)
                return;
            // Skip empty/placeholder networks unless they carry useful identifiers
            if (((o.ssid && o.ssid.length > 0) || (o.bssid && o.bssid.length > 0)))
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

            // Start a new entry only when a new row begins; IN-USE appears first per network in multiline format.
            if (key === "IN-USE") {
                // The presence of IN-USE indicates the start of a new AP row.
                if (obj)
                    pushIfValid(obj);
                obj = net._newWifiEntry();
                obj.connected = (val === "*");
                continue;
            }

            // Some nmcli variants may start the row with SSID (e.g., hidden IN-USE). If there is no current obj, start one.
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
            else if (key === "FREQ") {
                obj.freq = val;
                // band inferred later during dedupe where strongest wins
            } else if (key === "IN-USE") // fallback if seen mid-row in odd outputs
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
        var devs = net.devices ? net.devices.slice() : [];
        var idx = -1;
        for (var i = 0; i < devs.length; i++)
            if (devs[i].interface === iface) {
                idx = i;
                break;
            }
        if (idx >= 0) {
            var merged = {};
            var src = devs[idx];
            for (var k in src)
                merged[k] = src[k];
            for (var k2 in details)
                merged[k2] = details[k2];
            devs[idx] = merged;
        } else {
            var obj = {
                interface: iface
            };
            for (var k3 in details)
                obj[k3] = details[k3];
            devs = devs.concat([obj]);
        }
        net.devices = devs;
    }

    // Tag wifiNetworks entries with saved/connected flags
    function _applySavedFlags() {
        if (!net.wifiNetworks)
            return;
        var savedSet = {};
        if (net.savedConnections)
            for (var i = 0; i < net.savedConnections.length; i++)
                savedSet[net.savedConnections[i].ssid] = true;
        // Active SSID
        var activeSsid = null;
        for (var a = 0; a < net.wifiNetworks.length; a++) {
            var cand = net.wifiNetworks[a];
            if (cand && cand.connected && cand.ssid) {
                activeSsid = cand.ssid;
                break;
            }
        }
        if (!activeSsid && net.activeDevice && net.activeDevice.type === "wifi" && net._isConnected(net.activeDevice.state))
            activeSsid = net.activeDevice.connectionName || null;

        // Build new array immutably
        var updated = [];
        for (var j = 0; j < net.wifiNetworks.length; j++) {
            var wn = net.wifiNetworks[j];
            var nw = {};
            for (var k in wn)
                nw[k] = wn[k];
            nw.saved = !!savedSet[wn.ssid];
            if (activeSsid && !nw.connected)
                nw.connected = (nw.ssid === activeSsid);
            updated.push(nw);
        }
        // Sort: connected first, then signal desc
        try {
            updated.sort(function (a, b) {
                var ca = a && a.connected ? 1 : 0;
                var cb = b && b.connected ? 1 : 0;
                if (cb !== ca)
                    return cb - ca;
                var sa = a && a.signal ? a.signal : 0;
                var sb = b && b.signal ? b.signal : 0;
                return sb - sa;
            });
        } catch (e) {}
        net.wifiNetworks = updated;
    }

    // Infer band label from frequency string like "5180 MHz"
    function _inferBandLabel(freqStr) {
        if (!freqStr)
            return "";
        var mhz = parseInt(String(freqStr));
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

    // Filter placeholders and collapse multiple BSSIDs per SSID; keep strongest and propagate connected
    function _dedupeWifiNetworks(arr) {
        if (!arr || arr.length === 0)
            return [];
        var map = {};
        for (var i = 0; i < arr.length; i++) {
            var e = arr[i] || {};
            var ssid = (e.ssid || "").trim();
            // Drop placeholders or empty SSIDs
            if (!ssid || ssid === "--")
                continue;
            var bandLbl = net._inferBandLabel(e.freq || "");
            if (!map[ssid]) {
                // Shallow copy to avoid mutating original entries unexpectedly
                map[ssid] = {
                    ssid: ssid,
                    bssid: e.bssid || "",
                    signal: e.signal || 0,
                    security: e.security || "",
                    freq: e.freq || "",
                    band: bandLbl,
                    connected: !!e.connected,
                    saved: !!e.saved
                };
            } else {
                var cur = map[ssid];
                // Propagate connected and saved flags if any entry has them
                cur.connected = cur.connected || !!e.connected;
                cur.saved = cur.saved || !!e.saved;
                // Prefer the strongest signal for display attributes (bssid, freq, security)
                var sig = e.signal || 0;
                if (sig > cur.signal) {
                    cur.signal = sig;
                    cur.bssid = e.bssid || cur.bssid;
                    cur.freq = e.freq || cur.freq;
                    cur.band = bandLbl || cur.band;
                    cur.security = e.security || cur.security;
                }
            }
        }
        // Convert to array and sort by signal desc (final ordering pinned later)
        var out = [];
        for (var k in map)
            out.push(map[k]);
        out.sort(function (a, b) {
            return (b.signal || 0) - (a.signal || 0);
        });
        return out;
    }

    // Request device details (dynamic Process)
    function _requestDeviceDetails(iface) {
        try {
            var qml = 'import Quickshell.Io; Process { id: p; stdout: StdioCollector {} }';
            var obj = Qt.createQmlObject(qml, net, "dynamicProc_");
            if (!obj) {
                Logger.error("NetworkService", "Failed to create dynamic process object");
                return;
            }
            obj.command = ["nmcli", "-m", "multiline", "-f", "ALL", "device", "show", iface];
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
                        ip4: net._stripCidr(map["IP4.ADDRESS[1]"] || map["IP4.ADDRESS"] || null),
                        ip6: map["IP6.ADDRESS[1]"] || map["IP6.ADDRESS"] || null,
                        connectionName: map["GENERAL.CONNECTION"] || map["CONNECTION"] || "",
                        connectionUuid: map["GENERAL.CON-UUID"] || map["CON-UUID"] || ""
                    };
                    net._mergeDeviceDetails(ifc, details);
                    if ((map["GENERAL.TYPE"] || map["TYPE"]) === "wifi") {
                        net.wifiInterface = ifc;
                        net.wifiIP = net._stripCidr(details.ip4 || net.wifiIP);
                    } else if ((map["GENERAL.TYPE"] || map["TYPE"]) === "ethernet") {
                        net.ethernetInterface = ifc;
                        net.ethernetIP = net._stripCidr(details.ip4 || net.ethernetIP);
                    }
                    net._updateDerivedState();
                    Logger.log("NetworkService", "Merged device details for", ifc, "-> mac=", details.mac, "connName=", details.connectionName, "connUuid=", details.connectionUuid, "ip4=", details.ip4);
                } catch (ex) {
                    Logger.error("NetworkService", "Failed parsing dynamic device show output:", ex);
                }
                obj.destroy();
            });
            obj.running = true;
        } catch (e) {
            Logger.error("NetworkService", "Unable to request device details:", e);
        }
    }

    // === Public API ===
    // Run nmcli scan for wifi
    function refreshWifiScan(iface) {
        Logger.log("NetworkService", "refreshWifiScan(iface=", iface, ")");
        var now = net._nowMs();
        if (net.scanning)
            return;
        if (!net.wifiRadioEnabled) {
            Logger.log("NetworkService", "wifi radio disabled; skip scan");
            net.wifiNetworks = [];
            return;
        }
        for (var di = 0; di < net.devices.length; di++) {
            var d = net.devices[di];
            if (d.interface === iface && d.state && d.state.indexOf("unavailable") !== -1) {
                Logger.log("NetworkService", "wifi device unavailable; skip scan");
                net.wifiNetworks = [];
                net.wifiNetworksChanged();
                return;
            }
        }
        if (net._cooldownActive(net.lastWifiScanAt, net.wifiScanCooldownMs, now)) {
            Logger.log("NetworkService", "wifi scan cooldown active");
            return;
        }
        net.scanning = true;
        net.scanningChanged();
        try {
            procWifiList.command = ["nmcli", "-m", "multiline", "-f", "IN-USE,SSID,BSSID,SIGNAL,SECURITY,FREQ", "device", "wifi", "list", "ifname", iface];
            procWifiList.running = true;
        } catch (e) {
            Logger.error("NetworkService", "Unable to run wifi scan");
            net.scanning = false;
            net.scanningChanged();
        }
    }
    function refreshDevices() {
        Logger.log("NetworkService", "refreshDevices()");
        var now = net._nowMs();
        if (net._cooldownActive(net.lastDevicesRefreshAt, net.deviceRefreshCooldownMs, now)) {
            Logger.log("NetworkService", "device refresh cooldown active");
            return;
        }
        net.lastDevicesRefreshAt = now;
        try {
            procListDevices.running = true;
        } catch (e) {
            Logger.error("NetworkService", "Unable to run device list:", e);
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
        Logger.log("NetworkService", "connectWifi(ssid=", ssid, ", iface=", iface, ", save=", save, ")");
        if (!iface || iface === "")
            iface = net._firstWifiInterface();
        // Suppress transient disconnects from switching networks
        net._markWifiSwitchSuppression(iface);
        if (save && name) {
            Logger.log("NetworkService", "adding connection con-name=", name, "ssid=", ssid);
            net._runProcConnect(["nmcli", "connection", "add", "type", "wifi", "ifname", iface, "con-name", name, "ssid", ssid]);
            return;
        }
        if (password)
            net._runProcConnect(["nmcli", "device", "wifi", "connect", ssid, "password", password, "ifname", iface]);
        else
            net._runProcConnect(["nmcli", "device", "wifi", "connect", ssid, "ifname", iface]);
    }

    function activateConnection(connId, iface) {
        Logger.log("NetworkService", "activateConnection(connId=", connId, ", iface=", iface, ")");
        net._markWifiSwitchSuppression(iface);
        net._runProcConnect(["nmcli", "connection", "up", "id", connId, "ifname", iface]);
    }

    function disconnect(iface) {
        Logger.log("NetworkService", "disconnect(iface=", iface, ")");
        // Mark suppression for this interface and type to avoid self-inflicted notifications
        var dtype = "";
        for (var i = 0; i < net.devices.length; i++)
            if (net.devices[i].interface === iface) {
                dtype = net.devices[i].type;
                break;
            }
        if (dtype)
            net._markSuppression(dtype, iface, net.suppressDisconnectMs);
        // OSD for user-initiated Ethernet off
        if (dtype === "ethernet" && net.osd)
            net.osd.showInfo(qsTr("Ethernet turned off"));
        net._runProcConnect(["nmcli", "device", "disconnect", iface]);
    }

    // Convenience: disconnect currently active wifi device
    function disconnectWifi() {
        var iface = net._firstWifiInterface();
        if (iface) {
            net._markSuppression("wifi", iface, net.suppressDisconnectMs);
            net.disconnect(iface);
        }
    }

    // Forget a saved Wi‑Fi connection by name or UUID
    function forgetWifi(identifier) {
        // rudimentary UUID detection
        var isUuid = net._isUuid(identifier);
        procForget.command = isUuid ? ["nmcli", "connection", "delete", "uuid", identifier] : ["nmcli", "connection", "delete", "id", identifier];
        try {
            procForget.running = true;
        } catch (e) {
            Logger.error("NetworkService", "Unable to start forget command:", e);
        }
    }

    function dumpState() {
        try {
            Logger.log("NetworkService", "DUMP STATE: devices=", JSON.stringify(net.devices));
        } catch (e) {
            Logger.log("NetworkService", "dumpState devices stringify failed:", e);
        }
        try {
            Logger.log("NetworkService", "DUMP STATE: wifiNetworks=", JSON.stringify(net.wifiNetworks));
        } catch (e) {
            Logger.log("NetworkService", "dumpState wifi stringify failed:", e);
        }
    }

    // Public API: set and toggle Wi‑Fi radio
    function setWifiRadio(enabled) {
        var arg = enabled ? "on" : "off";
        if (!enabled) // disabling wifi will disconnect
            net._markSuppression("wifi", net._firstWifiInterface(), net.suppressDisconnectMs);
        // OSD feedback for radio toggle
        try {
            if (net.osd)
                net.osd.showInfo(enabled ? qsTr("Wi‑Fi turned on") : qsTr("Wi‑Fi turned off"));
        } catch (e) {}
        net._runProcConnect(["nmcli", "radio", "wifi", arg]);
    }

    function toggleWifiRadio() {
        net.setWifiRadio(!net.wifiRadioEnabled);
    }

    // Connect helpers may briefly cause disconnects when switching networks
    function _markWifiSwitchSuppression(iface) {
        net._markSuppression("wifi", iface || net._firstWifiInterface(), net.suppressWifiSwitchMs);
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
        onTriggered: net.refreshWifi
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
                Logger.log("NetworkService", "Starting nmcli monitor");
                monitorProc.running = true;
            } catch (e) {
                net.usePollingFallback = true;
                Logger.log("NetworkService", "Failed to start monitor:", e);
            }
        }
        onRunningChanged: function () {
            if (!running) {
                net.usePollingFallback = true;
                Logger.log("NetworkService", "nmcli monitor stopped");
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
                    // Diagnostics: ensure devices is JSON-serialisable
                    try {
                        Logger.log("NetworkService", "devices JSON:", JSON.stringify(net.devices));
                    } catch (eDiagDev) {
                        Logger.warn("NetworkService", "devices not JSON-serialisable", eDiagDev);
                    }
                    net._updateDerivedState();
                    var devSummary = "devices=" + net.devices.length + ": ";
                    for (var d = 0; d < net.devices.length; d++) {
                        var dv = net.devices[d];
                        devSummary += dv.interface + "(" + dv.type + "," + dv.state + ") ";
                    }
                    Logger.log("NetworkService", "Parsed devices:", devSummary);
                    for (var i = 0; i < net.devices.length; i++) {
                        var dv = net.devices[i];
                        if (dv.type === "loopback" || dv.type === "wifi-p2p")
                            continue;
                        net._requestDeviceDetails(dv.interface);
                    }
                    var chosen = net._chooseActiveDevice(net.devices);
                    if (chosen) {
                        net.activeDevice = chosen;
                        Logger.log("NetworkService", "Active device:", net.activeDevice.interface, "type=", net.activeDevice.type, "state=", net.activeDevice.state, "connName=", net.activeDevice.connectionName, "ip4=", net.activeDevice.ip4);
                    }
                    // clear last error on successful parse
                    net.lastError = "";
                } catch (e) {
                    Logger.error("NetworkService", "Failed parsing device list:", e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: function () {
                var msg = (text || "").trim();
                if (msg.length > 0)
                    Logger.error("NetworkService", msg);
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
                    // Dedupe and filter before applying flags
                    net.wifiNetworks = net._dedupeWifiNetworks(parsed);
                    net._applySavedFlags();
                    // Diagnostics: ensure wifiNetworks is JSON-serialisable
                    try {
                        Logger.log("NetworkService", "wifiNetworks JSON:", JSON.stringify(net.wifiNetworks));
                    } catch (eDiagWifi) {
                        Logger.warn("NetworkService", "wifiNetworks not JSON-serialisable", eDiagWifi);
                    }
                    var ncount = net.wifiNetworks ? net.wifiNetworks.length : 0;
                    var top = [];
                    for (var k = 0; k < Math.min(5, ncount); k++)
                        top.push(net.wifiNetworks[k].ssid + "(" + net.wifiNetworks[k].signal + ")");
                    Logger.log("NetworkService", "Wifi scan results: count=", ncount, " top=", top.join(", "));
                    if (net.activeDevice && net.activeDevice.type === "wifi" && ncount > 0 && net._isConnected(net.activeDevice.state))
                        Logger.log("NetworkService", "Active wifi device:", net.activeDevice.interface, "connName=", net.activeDevice.connectionName);
                } catch (e) {
                    Logger.error("NetworkService", "Failed parsing wifi list:", e);
                }
                net.scanning = false;
                net.scanningChanged();
                net.lastWifiScanAt = net._nowMs();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: function () {
                var msg = (text || "").trim();
                if (msg.length > 0)
                    Logger.error("NetworkService", msg);
            }
        }
    }

    // Connect / generic executor
    Process {
        id: procConnect
        stdout: StdioCollector {
            onStreamFinished: function () {
                Logger.log("NetworkService", "Connect finished");
                net.refreshDevices();
                // saved connections may have changed
                try {
                    procSaved.running = true;
                } catch (e) {}
                // refresh wifi radio state as well
                try {
                    procWifiRadio.running = true;
                } catch (e2) {}
            }
        }
        stderr: StdioCollector {
            onStreamFinished: function () {
                var msg = (text || "").trim();
                if (msg.length > 0)
                    Logger.error("NetworkService", msg);
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
                    // Diagnostics: ensure savedConnections is JSON-serialisable
                    try {
                        Logger.log("NetworkService", "savedConnections JSON:", JSON.stringify(net.savedConnections));
                    } catch (eDiagSav) {
                        Logger.error("NetworkService", "savedConnections not JSON-serialisable", eDiagSav);
                    }
                } catch (e) {
                    Logger.error("NetworkService", "Failed parsing saved connections list");
                }
            }
        }
    }

    // Forget a saved Wi‑Fi connection
    Process {
        id: procForget
        stdout: StdioCollector {
            onStreamFinished: function () {
                Logger.log("NetworkService", "Forget finished");
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
        Logger.log("NetworkService", "Component.onCompleted - initializing, setting ready=true");
        net._bootStartedAt = Date.now();
        net._lastWifiConnected = false;
        net._lastEthernetConnected = false;
        net.ready = true;
        net.refresh();
        try {
            procSaved.running = true;
        } catch (e) {}
    }

    // Desktop notification process used by _notifyDesktop()
    Process {
        id: notifySendProc
    }
}
