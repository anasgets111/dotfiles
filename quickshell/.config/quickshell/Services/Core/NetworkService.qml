pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils
import qs.Services.SystemInfo

Singleton {
    id: net
    readonly property int defaultBootSuppressMs: 8000
    readonly property int defaultNotifyDebounceMs: 4000
    readonly property int defaultWifiScanCooldownMs: 10000
    readonly property int defaultDeviceRefreshCooldownMs: 1000
    readonly property int defaultDevicePollMs: 5000
    readonly property int defaultWifiPollMs: 30000
    readonly property int suppressDisconnectMs: 15000
    readonly property int suppressWifiSwitchMs: 20000

    property bool ready: false

    property var devices: []         // list of device objects
    property var wifiNetworks: []    // last scanned wifi networks
    property var activeDevice: null  // currently active device object
    property string networkStatus: "disconnected"   // "ethernet" | "wifi" | "disconnected"
    property string ethernetInterface: ""
    property bool ethernetConnected: false
    property string ethernetIP: ""
    property string wifiInterface: ""
    property bool wifiConnected: false
    property string wifiIP: ""
    property var savedConnections: []   // array of {ssid}
    property bool wifiRadioEnabled: true

    property bool scanning: false
    property int lastWifiScanAt: 0
    property int wifiScanCooldownMs: defaultWifiScanCooldownMs
    property int lastDevicesRefreshAt: 0
    property int deviceRefreshCooldownMs: defaultDeviceRefreshCooldownMs

    property bool usePollingFallback: false
    property int devicePollIntervalMs: defaultDevicePollMs
    property int wifiPollIntervalMs: defaultWifiPollMs

    property string lastError: ""

    property bool _lastWifiConnected: false
    property bool _lastEthernetConnected: false
    property int _bootSuppressMs: defaultBootSuppressMs
    property double _bootStartedAt: 0
    property double _wifiSuppressUntil: 0
    property double _ethSuppressUntil: 0
    property var _ifaceSuppressUntil: ({})
    property int _notifyDebounceMs: defaultNotifyDebounceMs
    property double _lastNotifyAt: 0

    signal error(string message)
    signal connectionChanged
    signal wifiRadioChanged

    function _nowMs() {
        return Date.now();
    }

    function _cooldownActive(lastAt, cooldownMs, now) {
        const n = now !== undefined ? now : net._nowMs();
        return (n - lastAt) < cooldownMs;
    }

    function _computeDerived(devs) {
        let wifiIf = "", ethIf = "";
        let wifiConn = false, ethConn = false;
        let wifiIp = "", ethIp = "";
        let wifiName = "", ethName = "";
        for (let index = 0; index < devs.length; index++) {
            const device = devs[index];
            const isConnected = net._isConnected(device.state);
            if (device.type === "wifi") {
                wifiIf = device.interface || wifiIf;
                wifiConn = wifiConn || isConnected;
                if (device.ip4)
                    wifiIp = net._stripCidr(device.ip4);
                if (isConnected && device.connectionName)
                    wifiName = device.connectionName;
            } else if (device.type === "ethernet") {
                ethIf = device.interface || ethIf;
                ethConn = ethConn || isConnected;
                if (device.ip4)
                    ethIp = net._stripCidr(device.ip4);
                if (isConnected && device.connectionName)
                    ethName = device.connectionName;
            }
        }
        const status = wifiConn ? "wifi" : (ethConn ? "ethernet" : "disconnected");
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

    function _notify(urgency, title, body) {
        const now = net._nowMs();
        if (now - net._lastNotifyAt < net._notifyDebounceMs)
            return;
        net._lastNotifyAt = now;
        let level = 0; // info
        const u = String(urgency || "normal").toLowerCase();
        if (u === "critical")
            level = 2;
        else
        // error
        if (u === "warn" || u === "warning")
            level = 1; // warn
        const t = String(title || "");
        const b = String(body || "");
        const msg = b && b.length > 0 ? (t.length > 0 ? (t + ": " + b) : b) : t;
        OSDService.showToast(msg, level);
    }

    function _notifyDesktop(urgency, title, body) {
        const now = net._nowMs();
        if (now - net._lastNotifyAt < net._notifyDebounceMs)
            return;
        net._lastNotifyAt = now;
        notifySendProc.command = ["notify-send", "-u", String(urgency || "normal"), String(title || ""), String(body || "")];
        notifySendProc.running = true;
    }

    function _markSuppression(type, iface, ms) {
        const until = net._nowMs() + (ms || 10000);
        if (type === "wifi")
            net._wifiSuppressUntil = Math.max(net._wifiSuppressUntil, until);
        if (type === "ethernet")
            net._ethSuppressUntil = Math.max(net._ethSuppressUntil, until);
        const ifaceStr = String(iface || "");
        if (ifaceStr.length > 0) {
            const m = net._ifaceSuppressUntil;
            m[ifaceStr] = Math.max(m[ifaceStr] || 0, until);
            net._ifaceSuppressUntil = m; // reassign for change notify
        }
    }

    function _isSuppressed(type, iface) {
        const now = net._nowMs();
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

    function _stripCidr(s) {
        if (!s)
            return s;
        const str = String(s);
        const idx = str.indexOf("/");
        return idx > 0 ? str.substring(0, idx) : str;
    }

    function _isConnected(state) {
        if (!state)
            return false;
        const s = String(state).toLowerCase().trim();
        return s.indexOf("connected") === 0;
    }

    function _isUuid(s) {
        const str = String(s);
        if (str.length !== 36)
            return false;
        const hy = {
            8: true,
            13: true,
            18: true,
            23: true
        };
        for (let i = 0; i < 36; i++) {
            const ch = str[i];
            if (hy[i]) {
                if (ch !== '-')
                    return false;
                continue;
            }
            const code = ch.charCodeAt(0);
            const isHex = (code >= 48 && code <= 57) || (code >= 65 && code <= 70) || (code >= 97 && code <= 102);
            if (!isHex)
                return false;
        }
        return true;
    }

    function _firstWifiInterface() {
        if (!net.devices)
            return "";
        for (let i = 0; i < net.devices.length; i++)
            if (net.devices[i].type === "wifi")
                return net.devices[i].interface || "";
        return "";
    }

    function _updateDerivedState() {
        const prevStatus = net.networkStatus;
        const prevWifi = net._lastWifiConnected;
        const prevEth = net._lastEthernetConnected;

        const derived = net._computeDerived(net.devices || []);
        net.wifiInterface = derived.wifiIf;
        net.wifiConnected = derived.wifiConn;
        net.wifiIP = derived.wifiIp;
        net.ethernetInterface = derived.ethIf;
        net.ethernetConnected = derived.ethConn;
        net.ethernetIP = derived.ethIp;
        net.networkStatus = derived.status;
        if (prevStatus !== net.networkStatus)
            net.connectionChanged();

        if (prevWifi && !derived.wifiConn && !net._isSuppressed("wifi", derived.wifiIf)) {
            const wifiTitle = qsTr("Wi‑Fi disconnected");
            const wifiBody = derived.wifiIf ? (qsTr("Interface ") + derived.wifiIf) : "";
            net._notify((derived.ethConn ? "low" : "normal"), wifiTitle, wifiBody);
        }
        if (prevEth && !derived.ethConn && !net._isSuppressed("ethernet", derived.ethIf)) {
            const ethTitle = qsTr("Ethernet disconnected");
            const ethBody = derived.ethIf ? (qsTr("Interface ") + derived.ethIf) : "";
            net._notify((derived.wifiConn ? "low" : "normal"), ethTitle, ethBody);
        }

        const bootDelta = net._nowMs() - net._bootStartedAt;
        if (!prevWifi && derived.wifiConn && bootDelta >= net._bootSuppressMs) {
            const ssidName = derived.wifiName && derived.wifiName.length ? derived.wifiName : derived.wifiIf;
            const wifiMsg = (ssidName ? (qsTr("SSID ") + ssidName) : "") + (derived.wifiIp ? (ssidName ? ", IP " : qsTr("IP ")) + derived.wifiIp : "");
            net._notifyDesktop("low", qsTr("Wi‑Fi connected"), wifiMsg);
        }
        if (!prevEth && derived.ethConn && bootDelta >= net._bootSuppressMs) {
            const ifaceName = derived.ethName && derived.ethName.length ? derived.ethName : derived.ethIf;
            const ethMsg = (ifaceName ? (qsTr("Interface ") + ifaceName) : "") + (derived.ethIp ? (ifaceName ? ", IP " : qsTr("IP ")) + derived.ethIp : "");
            net._notifyDesktop("low", qsTr("Ethernet connected"), ethMsg);
        }

        net._lastWifiConnected = derived.wifiConn;
        net._lastEthernetConnected = derived.ethConn;
    }

    function _parseDeviceListMultiline(text) {
        const devicesList = [];
        const lines = text.split(/\n+/);
        let current = {
            interface: ""
        };
        for (let index = 0; index < lines.length; index++) {
            const line = lines[index].trim();
            if (!line)
                continue;
            const colonIndex = line.indexOf(":");
            if (colonIndex <= 0)
                continue;
            const key = line.substring(0, colonIndex).trim();
            const val = line.substring(colonIndex + 1).trim();

            if (key === "GENERAL.DEVICE" || key === "DEVICE") {
                if (current.interface)
                    devicesList.push(current);
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
                continue;
            }
            if (!current)
                continue; // skip until we have a device

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
        if (current.interface)
            devicesList.push(current);
        return devicesList;
    }

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
        const wifiList = [];
        const lines = (text || "").split(/\n+/);
        let current = null;
        function pushIfValid(entry) {
            if (!entry)
                return;
            if (((entry.ssid && entry.ssid.length > 0) || (entry.bssid && entry.bssid.length > 0)))
                wifiList.push(entry);
        }
        for (let index = 0; index < lines.length; index++) {
            const line = lines[index];
            if (!line || line.trim().length === 0)
                continue;
            const colonIndex = line.indexOf(":");
            if (colonIndex <= 0)
                continue;
            const key = line.substring(0, colonIndex).trim();
            const val = line.substring(colonIndex + 1).trim();

            if (key === "IN-USE") {
                if (current)
                    pushIfValid(current);
                current = net._newWifiEntry();
                current.connected = (val === "*");
                continue;
            }

            if (!current)
                current = net._newWifiEntry();

            if (key === "SSID")
                current.ssid = val;
            else if (key === "BSSID")
                current.bssid = val;
            else if (key === "SIGNAL")
                current.signal = parseInt(val) || 0;
            else if (key === "SECURITY")
                current.security = val;
            else if (key === "FREQ") {
                current.freq = val;
            } else if (key === "IN-USE") // fallback if seen mid-row in odd outputs
                current.connected = (val === "*");
        }
        pushIfValid(current);
        return wifiList;
    }

    function _chooseActiveDevice(devs) {
        if (!devs || devs.length === 0)
            return null;
        let wifiDevice = null, ethDevice = null, otherDevice = null, loopbackDevice = null;
        for (let index = 0; index < devs.length; index++) {
            const device = devs[index];
            if (!net._isConnected(device.state)) {
                if (device.type === "loopback")
                    loopbackDevice = device;
                continue;
            }
            if (device.type === "wifi" && !wifiDevice)
                wifiDevice = device;
            else if (device.type === "ethernet" && !ethDevice)
                ethDevice = device;
            else if (device.type !== "loopback" && !otherDevice)
                otherDevice = device;
            else if (device.type === "loopback" && !loopbackDevice)
                loopbackDevice = device;
        }
        return wifiDevice || ethDevice || otherDevice || (function () {
                let hasNonLoop = false;
                for (let j = 0; j < devs.length; j++)
                    if (devs[j].type !== "loopback") {
                        hasNonLoop = true;
                        break;
                    }
                return hasNonLoop ? null : loopbackDevice;
            })();
    }

    function _mergeDeviceDetails(iface, details) {
        let devices = net.devices ? net.devices.slice() : [];
        let foundIndex = -1;
        for (let index = 0; index < devices.length; index++)
            if (devices[index].interface === iface) {
                foundIndex = index;
                break;
            }
        if (foundIndex >= 0) {
            const existing = devices[foundIndex];
            const mergedDetails = Object.assign({}, existing, details);
            devices[foundIndex] = mergedDetails;
        } else {
            const newEntry = Object.assign({
                interface: iface
            }, details);
            devices = devices.concat([newEntry]);
        }
        net.devices = devices;
    }

    function _applySavedFlags() {
        if (!net.wifiNetworks)
            return;
        const savedSet = {};
        if (net.savedConnections)
            for (let index = 0; index < net.savedConnections.length; index++)
                savedSet[net.savedConnections[index].ssid] = true;
        let activeSsid = null;
        for (let idx = 0; idx < net.wifiNetworks.length; idx++) {
            const candidate = net.wifiNetworks[idx];
            if (candidate && candidate.connected && candidate.ssid) {
                activeSsid = candidate.ssid;
                break;
            }
        }
        if (!activeSsid && net.activeDevice && net.activeDevice.type === "wifi" && net._isConnected(net.activeDevice.state))
            activeSsid = net.activeDevice.connectionName || null;

        const updated = [];
        for (let j = 0; j < net.wifiNetworks.length; j++) {
            const network = net.wifiNetworks[j];
            const networkCopy = {};
            for (var key in network)
                networkCopy[key] = network[key];
            networkCopy.saved = !!savedSet[network.ssid];
            if (activeSsid && !networkCopy.connected)
                networkCopy.connected = (networkCopy.ssid === activeSsid);
            updated.push(networkCopy);
        }
        try {
            updated.sort(function (a, b) {
                const connectedA = a && a.connected ? 1 : 0;
                const connectedB = b && b.connected ? 1 : 0;
                if (connectedB !== connectedA)
                    return connectedB - connectedA;
                const signalA = a && a.signal ? a.signal : 0;
                const signalB = b && b.signal ? b.signal : 0;
                return signalB - signalA;
            });
        } catch (e) {}
        net.wifiNetworks = updated;
    }

    function _inferBandLabel(freqStr) {
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

    function _dedupeWifiNetworks(arr) {
        if (!arr || arr.length === 0)
            return [];
        const ssidMap = {};
        for (let index = 0; index < arr.length; index++) {
            const entry = arr[index] || {};
            const ssid = (entry.ssid || "").trim();
            if (!ssid || ssid === "--")
                continue;
            const bandLabel = net._inferBandLabel(entry.freq || "");
            if (!ssidMap[ssid]) {
                ssidMap[ssid] = {
                    ssid: ssid,
                    bssid: entry.bssid || "",
                    signal: entry.signal || 0,
                    security: entry.security || "",
                    freq: entry.freq || "",
                    band: bandLabel,
                    connected: !!entry.connected,
                    saved: !!entry.saved
                };
            } else {
                const current = ssidMap[ssid];
                current.connected = current.connected || !!entry.connected;
                current.saved = current.saved || !!entry.saved;
                const signalStrength = entry.signal || 0;
                if (signalStrength > current.signal) {
                    current.signal = signalStrength;
                    current.bssid = entry.bssid || current.bssid;
                    current.freq = entry.freq || current.freq;
                    current.band = bandLabel || current.band;
                    current.security = entry.security || current.security;
                }
            }
        }
        const result = [];
        for (var key in ssidMap)
            result.push(ssidMap[key]);
        result.sort(function (a, b) {
            return (b.signal || 0) - (a.signal || 0);
        });
        return result;
    }

    function _requestDeviceDetails(iface) {
        try {
            const qmlSnippet = 'import Quickshell.Io; Process { id: p; stdout: StdioCollector {} }';
            const proc = Qt.createQmlObject(qmlSnippet, net, "dynamicProc_");
            if (!proc) {
                Logger.error("NetworkService", "Failed to create dynamic process object");
                return;
            }
            proc.command = ["nmcli", "-m", "multiline", "-f", "ALL", "device", "show", iface];
            proc.stdout.streamFinished.connect(function () {
                try {
                    const textOutput = proc.stdout.text || "";
                    const fieldMap = {};
                    const lines = textOutput.trim().split(/\n+/);
                    for (let index = 0; index < lines.length; index++) {
                        const line = lines[index];
                        const colonIndex = line.indexOf(":");
                        if (colonIndex > 0) {
                            const field = line.substring(0, colonIndex).trim();
                            const value = line.substring(colonIndex + 1).trim();
                            fieldMap[field] = value;
                        }
                    }
                    const ifaceName = fieldMap["GENERAL.DEVICE"] || fieldMap["DEVICE"] || iface;
                    const details = {
                        mac: fieldMap["GENERAL.HWADDR"] || fieldMap["HWADDR"] || "",
                        type: fieldMap["GENERAL.TYPE"] || fieldMap["TYPE"] || "",
                        ip4: net._stripCidr(fieldMap["IP4.ADDRESS[1]"] || fieldMap["IP4.ADDRESS"] || null),
                        ip6: fieldMap["IP6.ADDRESS[1]"] || fieldMap["IP6.ADDRESS"] || null,
                        connectionName: fieldMap["GENERAL.CONNECTION"] || fieldMap["CONNECTION"] || "",
                        connectionUuid: fieldMap["GENERAL.CON-UUID"] || fieldMap["CON-UUID"] || ""
                    };
                    net._mergeDeviceDetails(ifaceName, details);
                    if ((fieldMap["GENERAL.TYPE"] || fieldMap["TYPE"]) === "wifi") {
                        net.wifiInterface = ifaceName;
                        net.wifiIP = net._stripCidr(details.ip4 || net.wifiIP);
                    } else if ((fieldMap["GENERAL.TYPE"] || fieldMap["TYPE"]) === "ethernet") {
                        net.ethernetInterface = ifaceName;
                        net.ethernetIP = net._stripCidr(details.ip4 || net.ethernetIP);
                    }
                    net._updateDerivedState();
                    Logger.log("NetworkService", "Merged device details for", ifaceName, "-> mac=", details.mac, "connName=", details.connectionName, "connUuid=", details.connectionUuid, "ip4=", details.ip4);
                } catch (ex) {
                    Logger.error("NetworkService", "Failed parsing dynamic device show output:", ex);
                }
                proc.destroy();
            });
            proc.running = true;
        } catch (e) {
            Logger.error("NetworkService", "Unable to request device details:", e);
        }
    }

    // === Public API ===
    function refreshWifiScan(iface) {
        Logger.log("NetworkService", "refreshWifiScan(iface=", iface, ")");
        const nowMs = net._nowMs();
        if (net.scanning)
            return;
        if (!net.wifiRadioEnabled) {
            Logger.log("NetworkService", "wifi radio disabled; skip scan");
            net.wifiNetworks = [];
            return;
        }
        for (let deviceIndex = 0; deviceIndex < net.devices.length; deviceIndex++) {
            const device = net.devices[deviceIndex];
            if (device.interface === iface && device.state && device.state.indexOf("unavailable") !== -1) {
                Logger.log("NetworkService", "wifi device unavailable; skip scan");
                net.wifiNetworks = [];
                net.wifiNetworksChanged();
                return;
            }
        }
        if (net._cooldownActive(net.lastWifiScanAt, net.wifiScanCooldownMs, nowMs)) {
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
        const nowMs = net._nowMs();
        if (net._cooldownActive(net.lastDevicesRefreshAt, net.deviceRefreshCooldownMs, nowMs)) {
            Logger.log("NetworkService", "device refresh cooldown active");
            return;
        }
        net.lastDevicesRefreshAt = nowMs;
        try {
            procListDevices.running = true;
        } catch (e) {
            Logger.error("NetworkService", "Unable to run device list:", e);
        }
    }

    function refresh() {
        net.lastError = "";
        net.refreshDevices();
        const wifiIface = net._firstWifiInterface();
        if (wifiIface && net.wifiRadioEnabled)
            net.refreshWifiScan(wifiIface);
        try {
            procWifiRadio.running = true;
        } catch (e2) {}
    }

    function refreshWifi() {
        const wifiIface = net._firstWifiInterface();
        if (wifiIface)
            net.refreshWifiScan(wifiIface);
    }

    function connectWifi(ssid, password, iface, save = false, name) {
        Logger.log("NetworkService", "connectWifi(ssid=", ssid, ", iface=", iface, ", save=", save, ")");
        if (!iface || iface === "")
            iface = net._firstWifiInterface();
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
        let deviceType = "";
        for (let index = 0; index < net.devices.length; index++)
            if (net.devices[index].interface === iface) {
                deviceType = net.devices[index].type;
                break;
            }
        if (deviceType)
            net._markSuppression(deviceType, iface, net.suppressDisconnectMs);
        if (deviceType === "ethernet")
            OSDService.showInfo(qsTr("Ethernet turned off"));
        net._runProcConnect(["nmcli", "device", "disconnect", iface]);
    }

    function disconnectWifi() {
        const wifiIface = net._firstWifiInterface();
        if (wifiIface) {
            net._markSuppression("wifi", wifiIface, net.suppressDisconnectMs);
            net.disconnect(wifiIface);
        }
    }

    function forgetWifi(identifier) {
        const isUuid = net._isUuid(identifier);
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

    function setWifiRadio(enabled) {
        const arg = enabled ? "on" : "off";
        if (!enabled) // disabling wifi will disconnect
            net._markSuppression("wifi", net._firstWifiInterface(), net.suppressDisconnectMs);
        OSDService.showInfo(enabled ? qsTr("Wi‑Fi turned on") : qsTr("Wi‑Fi turned off"));
        net._runProcConnect(["nmcli", "radio", "wifi", arg]);
    }

    function toggleWifiRadio() {
        net.setWifiRadio(!net.wifiRadioEnabled);
    }

    function _markWifiSwitchSuppression(iface) {
        net._markSuppression("wifi", iface || net._firstWifiInterface(), net.suppressWifiSwitchMs);
    }

    // === Timers ===
    Timer {
        id: monitorDebounce
        interval: 500
        repeat: false
        running: false
        onTriggered: {
            net.refresh();
        }
    }

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

    Process {
        id: procWifiRadio
        command: ["nmcli", "-t", "-f", "WIFI", "general"]
        stdout: StdioCollector {
            onStreamFinished: function () {
                try {
                    const stateText = (text || "").trim().toLowerCase();
                    const isEnabled = (stateText.indexOf("enabled") !== -1 || stateText === "yes" || stateText === "on");
                    if (net.wifiRadioEnabled !== isEnabled) {
                        net.wifiRadioEnabled = isEnabled;
                        net.wifiRadioChanged();
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: procListDevices
        command: ["nmcli", "-m", "multiline", "-f", "DEVICE,TYPE,STATE,CONNECTION,CON-UUID", "device"]
        stdout: StdioCollector {
            onStreamFinished: function () {
                try {
                    const parsedDevices = net._parseDeviceListMultiline(text);
                    net.devices = parsedDevices;
                    // Diagnostics: ensure devices is JSON-serialisable
                    try {
                        Logger.log("NetworkService", "devices JSON:", JSON.stringify(net.devices));
                    } catch (eDiagDev) {
                        Logger.warn("NetworkService", "devices not JSON-serialisable", eDiagDev);
                    }
                    net._updateDerivedState();
                    let devicesSummary = "devices=" + net.devices.length + ": ";
                    for (let d = 0; d < net.devices.length; d++) {
                        const device = net.devices[d];
                        devicesSummary += device.interface + "(" + device.type + "," + device.state + ") ";
                    }
                    Logger.log("NetworkService", "Parsed devices:", devicesSummary);
                    for (let i = 0; i < net.devices.length; i++) {
                        const device = net.devices[i];
                        if (device.type === "loopback" || device.type === "wifi-p2p")
                            continue;
                        net._requestDeviceDetails(device.interface);
                    }
                    const active = net._chooseActiveDevice(net.devices);
                    if (active) {
                        net.activeDevice = active;
                        Logger.log("NetworkService", "Active device:", net.activeDevice.interface, "type=", net.activeDevice.type, "state=", net.activeDevice.state, "connName=", net.activeDevice.connectionName, "ip4=", net.activeDevice.ip4);
                    }
                    net.lastError = "";
                } catch (e) {
                    Logger.error("NetworkService", "Failed parsing device list:", e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: function () {
                const errMsg = (text || "").trim();
                if (errMsg.length > 0)
                    Logger.error("NetworkService", errMsg);
            }
        }
    }

    Process {
        id: procWifiList
        stdout: StdioCollector {
            onStreamFinished: function () {
                try {
                    const parsedWifi = net._parseWifiListMultiline(text);
                    net.wifiNetworks = net._dedupeWifiNetworks(parsedWifi);
                    net._applySavedFlags();
                    try {
                        Logger.log("NetworkService", "wifiNetworks JSON:", JSON.stringify(net.wifiNetworks));
                    } catch (eDiagWifi) {
                        Logger.warn("NetworkService", "wifiNetworks not JSON-serialisable", eDiagWifi);
                    }
                    const networkCount = net.wifiNetworks ? net.wifiNetworks.length : 0;
                    const topList = [];
                    for (let k = 0; k < Math.min(5, networkCount); k++)
                        topList.push(net.wifiNetworks[k].ssid + "(" + net.wifiNetworks[k].signal + ")");
                    Logger.log("NetworkService", "Wifi scan results: count=", networkCount, " top=", topList.join(", "));
                    if (net.activeDevice && net.activeDevice.type === "wifi" && networkCount > 0 && net._isConnected(net.activeDevice.state))
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
                const errMsg = (text || "").trim();
                if (errMsg.length > 0)
                    Logger.error("NetworkService", errMsg);
            }
        }
    }

    Process {
        id: procConnect
        stdout: StdioCollector {
            onStreamFinished: function () {
                Logger.log("NetworkService", "Connect finished");
                net.refreshDevices();
                try {
                    procSaved.running = true;
                } catch (e) {}
                try {
                    procWifiRadio.running = true;
                } catch (e2) {}
            }
        }
        stderr: StdioCollector {
            onStreamFinished: function () {
                const errMsg = (text || "").trim();
                if (errMsg.length > 0)
                    Logger.error("NetworkService", errMsg);
            }
        }
    }

    Process {
        id: procSaved
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: function () {
                try {
                    const list = [];
                    const lines = text.trim().split(/\n+/);
                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i].trim();
                        if (!line)
                            continue;
                        const parts = line.split(":");
                        if (parts.length >= 2 && parts[1] === "802-11-wireless")
                            list.push({
                                ssid: parts[0]
                            });
                    }
                    net.savedConnections = list;
                    net._applySavedFlags();
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

    Process {
        id: procForget
        stdout: StdioCollector {
            onStreamFinished: function () {
                Logger.log("NetworkService", "Forget finished");
                net.refresh();
                try {
                    procSaved.running = true;
                } catch (e) {}
            }
        }
    }

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

    Process {
        id: notifySendProc
    }
}
