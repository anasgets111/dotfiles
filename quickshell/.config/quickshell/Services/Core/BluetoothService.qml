pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: root

  property int _revision: 0
  readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
  readonly property var audioKeywords: ["headset", "audio", "headphone", "airpod", "arctis", "speaker"]
  readonly property bool available: adapter !== null
  readonly property var codecMap: ({
      LDAC: {
        name: "LDAC",
        desc: "Highest quality",
        color: "#4CAF50"
      },
      APTX_HD: {
        name: "aptX HD",
        desc: "High quality",
        color: "#FF9800"
      },
      APTX: {
        name: "aptX",
        desc: "Good quality",
        color: "#FF9800"
      },
      AAC: {
        name: "AAC",
        desc: "Balanced",
        color: "#2196F3"
      },
      SBC_XQ: {
        name: "SBC-XQ",
        desc: "Enhanced SBC",
        color: "#2196F3"
      },
      SBC: {
        name: "SBC",
        desc: "Basic",
        color: "#9E9E9E"
      },
      MSBC: {
        name: "mSBC",
        desc: "Speech",
        color: "#9E9E9E"
      },
      CVSD: {
        name: "CVSD",
        desc: "Legacy speech",
        color: "#9E9E9E"
      }
    })
  property string connectAfterPairAddress: ""
  // Consumers bind to deviceCodecs[address]; emit change signals after object mutation.
  property var deviceAvailableCodecs: ({})
  property var deviceCodecs: ({})
  readonly property var deviceIconMap: [[["display", "tv", "[tv]", "television"], "󰔂"], [["watch"], "󰥔"], [["mouse"], "󰍽"], [["keyboard"], "󰌌"], [["phone", "iphone", "android", "samsung"], "󰄜"], [audioKeywords, "󰋋"]]
  readonly property var deviceModels: root.buildDeviceModels(root._revision)
  readonly property var devices: available ? adapter.devices.values : []
  readonly property bool discoverable: available && adapter.discoverable
  readonly property bool discovering: available && adapter.discovering
  property bool discoveryOwned: false
  readonly property bool enabled: available && adapter.enabled

  function _bumpRevision(): void {
    root._revision++;
  }

  function bluezCardName(address: string): string {
    return `bluez_card.${address.replace(/:/g, "_")}`;
  }

  function buildDeviceModels(revision: int): var {
    return root.devices.map(device => root.toDeviceModel(device)).sort((leftModel, rightModel) => {
      if (leftModel.connected !== rightModel.connected)
        return rightModel.connected - leftModel.connected;
      if (leftModel.paired !== rightModel.paired)
        return rightModel.paired - leftModel.paired;
      return leftModel.name.localeCompare(rightModel.name);
    });
  }

  function canConnect(device: BluetoothDevice): bool {
    return !!device?.paired && !device.connected && !isDeviceBusy(device) && !device.blocked;
  }

  function canPair(device: BluetoothDevice): bool {
    return !!device && !device.paired && !device.blocked && !isDeviceBusy(device);
  }

  function cleanupCodecData(address: string): void {
    if (!address)
      return;
    if (codecParser.address === address)
      codecParser.address = "";
    delete deviceCodecs[address];
    delete deviceAvailableCodecs[address];
    deviceCodecsChanged();
    deviceAvailableCodecsChanged();
  }

  function clearPendingPair(device: BluetoothDevice): void {
    if (device?.address === connectAfterPairAddress)
      connectAfterPairAddress = "";
  }

  function connectDevice(address: string): void {
    const device = root.deviceForAddress(address);
    if (!device || device.blocked || isDeviceBusy(device) || device.connected || !device.paired)
      return;
    device.trusted = true;
    device.connect();
  }

  function deviceForAddress(address: string): BluetoothDevice {
    return root.adapter?.devices?.get(address) ?? null;
  }

  function deviceMatchesKeywords(device: BluetoothDevice, keywords: var): bool {
    const searchText = `${device?.icon || ""} ${getDeviceName(device)}`.toLowerCase();
    return keywords.some(keyword => searchText.includes(keyword));
  }

  function disconnectDevice(address: string): void {
    const device = root.deviceForAddress(address);
    if (!device)
      return;
    clearPendingPair(device);
    device.disconnect();
    cleanupCodecData(address);
  }

  function fetchCodecs(address: string, fullScan = true): void {
    const device = root.deviceForAddress(address);
    if (!device?.connected || !isAudioDevice(device) || codecParser.running)
      return;
    codecParser.address = address;
    codecParser.cardName = root.bluezCardName(address);
    codecParser.fullScan = fullScan;
    codecParser.running = true;
  }

  function forgetDevice(address: string): void {
    const device = root.deviceForAddress(address);
    if (!device)
      return;
    clearPendingPair(device);
    device.trusted = false;
    device.forget();
    cleanupCodecData(address);
  }

  function getBattery(device: BluetoothDevice): string {
    return device?.batteryAvailable && device.battery > 0 ? `${Math.round(device.battery * 100)}%` : "";
  }

  function getCodecInfo(name: string): var {
    const key = (name || "").replace(/-/g, "_").toUpperCase();
    return codecMap[key] ?? {
      name: name || "",
      desc: "Unknown",
      color: "#9E9E9E"
    };
  }

  function getDeviceIcon(device: BluetoothDevice): string {
    if (!device)
      return "󰂯";
    for (const [keywords, glyph] of deviceIconMap) {
      if (deviceMatchesKeywords(device, keywords))
        return glyph;
    }
    return "󰂯";
  }

  function getDeviceName(device: BluetoothDevice): string {
    return device?.name || device?.deviceName || "";
  }

  function getStatusString(device: BluetoothDevice): string {
    if (!device)
      return "";
    if (device.state === BluetoothDeviceState.Connecting)
      return "Connecting...";
    if (device.pairing)
      return "Pairing...";
    if (device.blocked)
      return "Blocked";
    return "";
  }

  function isAudioDevice(device: BluetoothDevice): bool {
    return !!device && deviceMatchesKeywords(device, audioKeywords);
  }

  function isDeviceBusy(device: BluetoothDevice): bool {
    return device?.pairing || device?.state === BluetoothDeviceState.Disconnecting || device?.state === BluetoothDeviceState.Connecting;
  }

  function pairDevice(address: string): void {
    const device = root.deviceForAddress(address);
    if (!device || device.blocked || device.paired || device.pairing)
      return;
    connectAfterPairAddress = address;
    device.trusted = true;
    device.pair();
  }

  function parseCodecLine(line: string): void {
    if (line.startsWith("Name: ")) {
      codecParser.inCard = line.includes(codecParser.cardName);
      return;
    }
    if (!codecParser.inCard)
      return;
    if (line.startsWith("Active Profile:")) {
      codecParser.activeProfile = line.split(": ")[1] || "";
      return;
    }
    if (!line.includes("codec") || !line.includes("available: yes"))
      return;
    const parts = line.split(": ");
    if (parts.length < 2)
      return;
    const profile = parts[0].trim();
    const codecMatch = parts[1].match(/codec ([^\)\s]+)/i);
    const codecName = codecMatch ? codecMatch[1].toUpperCase() : "UNKNOWN";
    const codecInfo = getCodecInfo(codecName);
    if (!codecParser.parsedCodecs.some(codec => codec.profile === profile))
      codecParser.parsedCodecs.push({
        name: codecInfo.name,
        profile,
        description: codecInfo.desc,
        qualityColor: codecInfo.color
      });
  }

  function setDiscoverable(value: bool): void {
    Logger.log("BluetoothService", `Set discoverable: ${value} (available=${available})`);
    if (adapter)
      adapter.discoverable = value;
  }

  function setEnabled(value: bool): void {
    Logger.log("BluetoothService", `Set enabled: ${value} (available=${available})`);
    if (!adapter)
      return;
    if (!value && adapter.discovering)
      adapter.discovering = false;
    if (value) {
      adapter.enabled = true;
      return;
    }
    Qt.callLater(() => {
      if (root.adapter)
        root.adapter.enabled = false;
    });
  }

  function startDiscovery(): void {
    if (!adapter?.enabled || adapter.discovering)
      return;
    discoveryOwned = true;
    adapter.discovering = true;
  }

  function stopDiscovery(): void {
    if (adapter?.enabled && adapter.discovering && discoveryOwned)
      adapter.discovering = false;
    discoveryOwned = false;
  }

  function switchCodec(address: string, profile: string): void {
    if (!address || codecSwitch.running)
      return;
    codecSwitch.cardName = root.bluezCardName(address);
    codecSwitch.profile = profile;
    codecSwitch.deviceAddress = address;
    codecSwitch.running = true;
  }

  function toDeviceModel(device: BluetoothDevice): var {
    const address = device?.address || "";
    return {
      address,
      name: root.getDeviceName(device) || qsTr("Unknown"),
      icon: root.getDeviceIcon(device),
      statusText: root.getStatusString(device),
      connected: !!device?.connected,
      paired: !!device?.paired,
      blocked: !!device?.blocked,
      busy: root.isDeviceBusy(device),
      isAudio: root.isAudioDevice(device),
      hasBattery: !!(device?.batteryAvailable && device.battery > 0),
      battery: device?.batteryAvailable && device.battery > 0 ? Math.round(device.battery * 100) : 0,
      batteryText: root.getBattery(device),
      canConnect: root.canConnect(device),
      canPair: root.canPair(device),
      currentCodec: root.deviceCodecs[address] || "",
      availableCodecs: root.deviceAvailableCodecs[address] || []
    };
  }

  Component.onCompleted: Logger.log("BluetoothService", `Init: defaultAdapter=${Bluetooth.defaultAdapter ? "yes" : "no"}`)
  Component.onDestruction: {
    codecParser.running = false;
    codecSwitch.running = false;
  }

  Connections {
    function onDiscoveringChanged() {
      if (!root.adapter?.discovering)
        root.discoveryOwned = false;
    }

    function onEnabledChanged() {
      if (!root.adapter?.enabled)
        root.discoveryOwned = false;
    }

    target: root.adapter
  }

  Connections {
    function onDefaultAdapterChanged() {
      const defaultAdapter = Bluetooth.defaultAdapter;
      Logger.log("BluetoothService", `Default adapter changed: ${defaultAdapter ? "set" : "none"}`);
    }

    target: Bluetooth
  }

  Instantiator {
    model: root.devices

    delegate: QtObject {
      id: deviceEntry

      readonly property string address: modelData?.address || ""
      readonly property Connections deviceConn: Connections {
        function onBatteryAvailableChanged() {
          root._bumpRevision();
        }

        function onBatteryChanged() {
          root._bumpRevision();
        }

        function onBlockedChanged() {
          root._bumpRevision();
        }

        function onConnectedChanged() {
          root._bumpRevision();
        }

        function onPairedChanged() {
          root._bumpRevision();
        }

        function onPairingChanged() {
          root._bumpRevision();
          if (deviceEntry.modelData?.pairing || deviceEntry.address !== root.connectAfterPairAddress)
            return;
          root.connectAfterPairAddress = "";
          if (deviceEntry.modelData?.paired)
            Qt.callLater(() => root.connectDevice(deviceEntry.address));
        }

        function onStateChanged() {
          root._bumpRevision();
        }

        ignoreUnknownSignals: true
        target: deviceEntry.modelData
      }
      required property BluetoothDevice modelData
    }
  }

  Process {
    id: codecParser

    property string activeProfile: ""
    property string address: ""
    property string cardName: ""
    property bool fullScan: true
    property bool inCard: false
    property var parsedCodecs: []

    command: ["pactl", "list", "cards"]

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: line => root.parseCodecLine(line.trim())
    }

    onRunningChanged: {
      if (running) {
        parsedCodecs = [];
        activeProfile = "";
        inCard = false;
      } else if (address) {
        if (fullScan) {
          root.deviceAvailableCodecs[address] = parsedCodecs;
          root.deviceAvailableCodecsChanged();
        }
        const activeCodec = parsedCodecs.find(codec => codec.profile === activeProfile);
        if (activeCodec) {
          root.deviceCodecs[address] = activeCodec.name;
          root.deviceCodecsChanged();
        }
        address = "";
        cardName = "";
      }
    }
  }

  Process {
    id: codecSwitch

    property string cardName: ""
    property string deviceAddress: ""
    property string profile: ""

    command: ["pactl", "set-card-profile", cardName, profile]

    onRunningChanged: {
      if (!running && deviceAddress) {
        const addr = deviceAddress;
        Qt.callLater(() => root.fetchCodecs(addr, false));
        deviceAddress = "";
        cardName = "";
        profile = "";
      }
    }
  }
}
