pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Services.Utils

Singleton {
  id: root

  property var _bandMap: ({})
  property string _ethernetIp: ""
  property bool _networkingEnabled: true
  property string _wifiIp: ""
  readonly property var availableWifiAps: {
    const savedNames = new Set(root.savedWifiAps.map(accessPoint => accessPoint.ssid));
    return root.wifiAps.filter(accessPoint => !savedNames.has(accessPoint.ssid) && accessPoint.signal > 0);
  }
  readonly property var connectedWifiAp: root.wifiAps.find(accessPoint => accessPoint.connected) || null
  readonly property string ethernetInterface: root.wiredDevice?.name ?? ""
  readonly property alias ethernetIpAddress: root._ethernetIp
  readonly property bool ethernetOnline: root.wiredNetwork?.connected ?? false
  readonly property int ethernetSpeed: root.wiredDevice?.linkSpeed ?? 0
  readonly property string linkType: root.ethernetOnline ? "ethernet" : (root.wifiOnline ? "wifi" : "disconnected")
  readonly property alias networkingEnabled: root._networkingEnabled
  readonly property bool ready: Networking.backend !== NetworkBackendType.None
  readonly property var savedWifiAps: root.wifiAps.filter(accessPoint => accessPoint.saved && (accessPoint.signal > 0 || accessPoint.connected))
  readonly property var viewWifiAps: root.savedWifiAps.filter(accessPoint => !accessPoint.connected).concat(root.availableWifiAps.filter(accessPoint => !accessPoint.connected))

  // --- Wifi state (native) ---
  readonly property var wifiAps: {
    const networks = root.wifiDevice?.networks.values ?? [];
    return networks.map(network => ({
          ssid: network.name,
          signal: Math.round(network.signalStrength * 100),
          band: root._bandMap[network.name] ?? "",
          security: root.securityLabel(network.security),
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

  function connectEthernet(): void {
    root.wiredNetwork?.connect();
  }

  function connectHiddenWifi(ssid: string, password: string): void {
    const trimmedSsid = (ssid || "").trim();
    const interfaceName = root.wifiInterface;
    if (!trimmedSsid || !interfaceName)
      return;
    const command = ["nmcli", "device", "wifi", "connect", trimmedSsid, "ifname", interfaceName, "hidden", "yes"];
    if (password)
      command.push("password", password);
    root.runCommand(cmdAction, command);
  }

  function connectionFailReasonText(reason: int): string {
    if (reason === ConnectionFailReason.NoSecrets)
      return qsTr("Wrong password");
    if (reason === ConnectionFailReason.WifiAuthTimeout)
      return qsTr("Connection timeout");
    if (reason === ConnectionFailReason.WifiNetworkLost)
      return qsTr("Network not found");
    return qsTr("Connection failed");
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

  function getBandColor(band: string): string {
    return band === "6" ? "#A6E3A1" : band === "5" ? "#89B4FA" : "#CDD6F4";
  }

  function getWifiIcon(band: string, signal: int): string {
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
    if (!interfaceName || procBand.running)
      return;
    root.runCommand(procBand, ["nmcli", "-t", "-f", "SSID,FREQ", "device", "wifi", "list", "ifname", interfaceName]);
  }

  function refreshIpData(): void {
    root.runCommand(procIp, ["nmcli", "-t", "-f", "GENERAL.DEVICE,IP4.ADDRESS", "device", "show"]);
  }

  function refreshNetworkingStatus(): void {
    root.runCommand(procStatus, ["nmcli", "-t", "-f", "NETWORKING", "general"]);
  }

  function rescanWifi(): void {
    const interfaceName = root.wifiInterface;
    if (!interfaceName)
      return;
    root.runCommand(cmdAction, ["nmcli", "device", "wifi", "rescan", "ifname", interfaceName]);
    root.refreshBandData();
  }

  function runCommand(process: Process, command: var): void {
    if (process.running)
      return;
    process.command = root.nmcliCommand(command);
    process.running = true;
  }

  function securityLabel(securityType: int): string {
    return (securityType !== WifiSecurityType.Open && securityType !== WifiSecurityType.Owe && securityType !== WifiSecurityType.Unknown) ? "secured" : "";
  }

  function setNetworkingEnabled(enabled: bool): void {
    root.runCommand(cmdAction, ["nmcli", "networking", enabled ? "on" : "off"]);
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

  Component.onCompleted: {
    procMonitor.running = true;
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

  // --- Fallback refresh trigger for nmcli-only data ---
  Process {
    id: procMonitor

    command: root.nmcliCommand(["nmcli", "monitor"])

    stdout: SplitParser {
      onRead: refreshTimer.restart()
    }

    onRunningChanged: if (!running)
      restartTimer.restart()
  }

  Timer {
    id: refreshTimer

    interval: 500

    onTriggered: {
      root.refreshIpData();
      root.refreshNetworkingStatus();
    }
  }

  Timer {
    id: restartTimer

    interval: 3000

    onTriggered: procMonitor.running = true
  }

  // --- Networking enabled (nmcli fallback) ---
  Process {
    id: procStatus

    stdout: StdioCollector {
      onStreamFinished: root._networkingEnabled = (text || "").trim() === "enabled"
    }
  }

  // --- IP addresses (nmcli fallback, native API does not expose them) ---
  Process {
    id: procIp

    stdout: StdioCollector {
      onStreamFinished: {
        const addressesByInterface = root.parseInterfaceAddresses(text);
        root._ethernetIp = addressesByInterface[root.ethernetInterface] ?? "";
        root._wifiIp = addressesByInterface[root.wifiInterface] ?? "";
      }
    }
  }

  // --- Band data: lightweight supplemental scan for frequency info ---
  Process {
    id: procBand

    stdout: StdioCollector {
      onStreamFinished: root._bandMap = root.parseWifiBands(text)
    }
  }

  // --- Hidden wifi / networking toggle command ---
  Process {
    id: cmdAction

    stderr: StdioCollector {
      onStreamFinished: {
        const error = (text || "").trim();
        if (error)
          Logger.log("NetworkService", `Error: ${error}`);
      }
    }
    stdout: StdioCollector {
      onStreamFinished: {
        root.refreshIpData();
        root.refreshNetworkingStatus();
      }
    }
  }
}
