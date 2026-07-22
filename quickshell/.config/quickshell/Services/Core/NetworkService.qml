pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Networking
import qs.Services.Utils

Singleton {
  id: root

  property var _bandMap: ({})
  property string _connectError: ""
  property var _connectHandle: null
  property string _connectingSsid: ""
  property string _defaultInterface: ""
  property string _ethernetIp: ""
  property bool _networkingEnabled: true
  property string _wifiIp: ""
  readonly property var availableWifiAps: {
    const savedNames = new Set(root.savedWifiAps.map(accessPoint => accessPoint.ssid));
    return root.wifiAps.filter(accessPoint => !savedNames.has(accessPoint.ssid) && accessPoint.signal > 0);
  }
  readonly property alias connectError: root._connectError
  readonly property var connectedWifiAp: root.wifiAps.find(accessPoint => accessPoint.connected) || null
  readonly property alias connectingSsid: root._connectingSsid
  readonly property string ethernetInterface: root.wiredDevice?.name ?? ""
  readonly property alias ethernetIpAddress: root._ethernetIp
  readonly property bool ethernetOnline: root.wiredNetwork?.connected ?? false
  readonly property int ethernetSpeed: root.wiredDevice?.linkSpeed ?? 0
  readonly property string linkType: root._defaultInterface === root.wifiInterface && root.wifiOnline ? "wifi" : root._defaultInterface === root.ethernetInterface && root.ethernetOnline ? "ethernet" : root.wifiOnline ? "wifi" : root.ethernetOnline ? "ethernet" : "disconnected"
  readonly property alias networkingEnabled: root._networkingEnabled
  readonly property bool ready: Networking.backend !== NetworkBackendType.None
  readonly property var savedWifiAps: root.wifiAps.filter(accessPoint => accessPoint.saved && (accessPoint.signal > 0 || accessPoint.connected))
  readonly property var viewWifiAps: root.savedWifiAps.filter(accessPoint => !accessPoint.connected).concat(root.availableWifiAps.filter(accessPoint => !accessPoint.connected))
  readonly property var wifiAps: {
    const networks = root.wifiDevice?.networks.values ?? [];
    return networks.map(network => ({
          ssid: network.name,
          signal: Math.round(network.signalStrength * 100),
          band: root._bandMap[network.name] ?? "",
          secured: root.isSecured(network.security),
          connected: network.connected,
          saved: network.known
        })).sort((leftAccessPoint, rightAccessPoint) => (rightAccessPoint.connected - leftAccessPoint.connected) || (rightAccessPoint.signal - leftAccessPoint.signal));
  }
  readonly property var wifiDevice: root.deviceOfType(DeviceType.Wifi)
  readonly property string wifiInterface: root.wifiDevice?.name ?? ""
  readonly property alias wifiIpAddress: root._wifiIp
  readonly property bool wifiOnline: root.wifiDevice?.connected ?? false
  readonly property bool wifiRadioEnabled: Networking.wifiEnabled
  readonly property var wiredDevice: root.deviceOfType(DeviceType.Wired)
  readonly property var wiredNetwork: root.wiredDevice?.network ?? null

  signal connectFailed(string ssid, string reason)
  signal connectSucceeded(string ssid)

  function _connectErrorText(output: string): string {
    const message = (output || "").toLowerCase();
    if (message.includes("secrets were required") || message.includes("no secrets"))
      return qsTr("Wrong password");
    if (message.includes("no network with ssid") || message.includes("not found"))
      return qsTr("Network not found");
    if (message.includes("timeout") || message.includes("timed out"))
      return qsTr("Connection timeout");
    return qsTr("Connection failed");
  }
  function _runAction(command: var): void {
    Command.run(root.nmcliCommand(command), result => {
      const error = (result.stderr || "").trim();
      if (error)
        Logger.log("NetworkService", `Error: ${error}`);
      root.refreshIpData();
      root.refreshNetworkingStatus();
    }, "net.action");
  }
  function cancelConnect(): void {
    const wasConnecting = root._connectingSsid !== "";
    root._connectHandle?.cancel();
    root._connectHandle = null;
    root._connectingSsid = "";
    root._connectError = "";
    if (wasConnecting)
      root.wifiDevice?.disconnect();
  }
  function connectEthernet(): void {
    root.wiredNetwork?.connect();
  }
  function connectToSsid(ssid: string, password: string): void {
    const target = String(ssid ?? "");
    if (!target || !root.wifiInterface || root._connectingSsid !== "")
      return;

    const secret = String(password ?? "");
    // ponytail: password-only prompting supports PSK; add a secret agent for enterprise auth.
    const command = ["nmcli"];
    if (secret)
      command.push("--ask");
    command.push("-w", "20", "device", "wifi", "connect", target, "ifname", root.wifiInterface);
    const hidden = !root.wifiNetworkForSsid(target);
    if (hidden)
      command.push("hidden", "yes");
    const handle = Command.run(root.nmcliCommand(command), result => {
      root._connectHandle = null;
      root.refreshIpData();
      root._connectingSsid = "";
      if (result.exitCode === 0) {
        root.connectSucceeded(target);
        return;
      }
      const reason = root._connectErrorText(`${result.stderr}\n${result.stdout}`);
      root._connectError = reason;
      root.connectFailed(target, reason);
    }, "net.connect", secret ? `${secret}\n` : "");
    if (!handle)
      return;
    root._connectHandle = handle;
    root._connectError = "";
    root._connectingSsid = target;
  }
  function deviceOfType(deviceType: int): var {
    for (const device of Networking.devices.values) {
      if (device.type === deviceType)
        return device;
    }
    return null;
  }
  function disconnectEthernet(): void {
    root.wiredDevice?.disconnect();
  }
  function disconnectWifi(): void {
    root.wifiDevice?.disconnect();
  }
  function forgetWifi(ssid: string): void {
    root.wifiNetworkForSsid(ssid)?.forget();
  }
  function getWifiIcon(signal: int): string {
    const normalizedSignal = Math.max(0, Math.min(100, signal | 0));
    return normalizedSignal >= 95 ? "󰤨" : normalizedSignal >= 80 ? "󰤥" : normalizedSignal >= 50 ? "󰤢" : "󰤟";
  }
  function inferBandLabel(frequencyText: string): string {
    const frequencyMhz = parseInt(String(frequencyText || "").split(" ")[0], 10);
    if (frequencyMhz >= 5925 && frequencyMhz <= 7200)
      return "6";
    if (frequencyMhz >= 4900 && frequencyMhz < 5925)
      return "5";
    if (frequencyMhz >= 2400 && frequencyMhz <= 2500)
      return "2.4";
    return "";
  }
  function isSecured(securityType: int): bool {
    return securityType !== WifiSecurityType.Open && securityType !== WifiSecurityType.Owe && securityType !== WifiSecurityType.Unknown;
  }
  function nmcliCommand(args: var): var {
    return ["env", "LC_ALL=C"].concat(args);
  }
  function parseInterfaceAddresses(nmcliOutput: string): var {
    const addressesByInterface = {};
    let currentInterface = "";

    for (const line of (nmcliOutput || "").split("\n")) {
      const fields = root.parseNmcliTerseLine(line.trim());
      if (fields.length < 2)
        continue;
      if (fields[0] === "GENERAL.DEVICE")
        currentInterface = fields[1];
      else if (currentInterface && fields[0].includes("IP4.ADDRESS") && !addressesByInterface[currentInterface])
        addressesByInterface[currentInterface] = fields[1].split("/")[0];
    }
    return addressesByInterface;
  }
  function parseNmcliTerseLine(line: string): var {
    const fields = [];
    let field = "";
    for (let index = 0; index < line.length; index++) {
      if (line[index] === '\\' && index + 1 < line.length)
        field += line[++index];
      else if (line[index] === ':') {
        fields.push(field);
        field = "";
      } else
        field += line[index];
    }
    fields.push(field);
    return fields;
  }
  function parseWifiBands(nmcliOutput: string): var {
    const bandsBySsid = {};
    for (const line of (nmcliOutput || "").split("\n")) {
      const fields = root.parseNmcliTerseLine(line);
      const ssid = fields[0] ?? "";
      if (fields.length < 2 || !ssid || ssid === "--")
        continue;
      const band = root.inferBandLabel(fields[1]);
      if (band)
        bandsBySsid[ssid] = band;
    }
    return bandsBySsid;
  }
  function refreshBandData(): void {
    const interfaceName = root.wifiInterface;
    if (!interfaceName)
      return;
    Command.run(root.nmcliCommand(["nmcli", "-t", "-f", "SSID,FREQ", "device", "wifi", "list", "ifname", interfaceName]), result => root._bandMap = root.parseWifiBands(result.stdout), "net.band");
  }
  function refreshIpData(): void {
    Command.run(root.nmcliCommand(["nmcli", "-t", "-f", "GENERAL.DEVICE,IP4.ADDRESS", "device", "show"]), result => {
      const addressesByInterface = root.parseInterfaceAddresses(result.stdout);
      root._ethernetIp = addressesByInterface[root.ethernetInterface] ?? "";
      root._wifiIp = addressesByInterface[root.wifiInterface] ?? "";
    }, "net.ip");
    Command.run(root.nmcliCommand(["ip", "route", "show", "default"]), result => {
      const match = (result.stdout || "").match(/\bdev\s+(\S+)/);
      root._defaultInterface = match?.[1] ?? "";
    }, "net.route");
  }
  function refreshNetworkingStatus(): void {
    Command.run(root.nmcliCommand(["nmcli", "-t", "-f", "NETWORKING", "general"]), result => root._networkingEnabled = (result.stdout || "").trim() === "enabled", "net.status");
  }
  function rescanWifi(): void {
    const interfaceName = root.wifiInterface;
    if (!interfaceName)
      return;
    root._runAction(["nmcli", "device", "wifi", "rescan", "ifname", interfaceName]);
    root.refreshBandData();
  }
  function setNetworkingEnabled(enabled: bool): void {
    root._runAction(["nmcli", "networking", enabled ? "on" : "off"]);
  }
  function setWifiRadioEnabled(enabled: bool): void {
    Networking.wifiEnabled = enabled;
  }
  function startWifiScan(): void {
    if (root.wifiDevice)
      root.wifiDevice.scannerEnabled = true;
    root.refreshBandData();
  }
  function stopWifiScan(): void {
    if (root.wifiDevice)
      root.wifiDevice.scannerEnabled = false;
  }
  function wifiNetworkForSsid(ssid: string): var {
    return (root.wifiDevice?.networks.values ?? []).find(network => network.name === ssid) ?? null;
  }

  Component.onCompleted: {
    root.refreshIpData();
    root.refreshNetworkingStatus();
    Logger.log("NetworkService", "ready");
  }
  onEthernetInterfaceChanged: root.refreshIpData()
  onEthernetOnlineChanged: root.refreshIpData()
  onWifiInterfaceChanged: {
    if (root.wifiInterface)
      root.refreshBandData();
    root.refreshIpData();
  }
  onWifiOnlineChanged: root.refreshIpData()

  CommandStream {
    id: procMonitor

    active: true
    command: root.nmcliCommand(["nmcli", "monitor"])
    restartDelay: 3000

    onLineRead: refreshTimer.restart()
  }
  Timer {
    id: refreshTimer

    interval: 500

    onTriggered: {
      root.refreshIpData();
      root.refreshNetworkingStatus();
    }
  }
}
