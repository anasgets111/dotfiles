pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: root

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
  // Codec data storage: Property bindings to deviceCodecs[addr] automatically react
  // when deviceCodecsChanged() is emitted. This is more ergonomic than signal-based
  // patterns which require manual Connections in every consumer.
  property var deviceAvailableCodecs: ({})
  property var deviceCodecs: ({})
  readonly property var deviceIconMap: [[["display", "tv", "[tv]", "television"], "󰔂"], [["watch"], "󰥔"], [["mouse"], "󰍽"], [["keyboard"], "󰌌"], [["phone", "iphone", "android", "samsung"], "󰄜"], [audioKeywords, "󰋋"]]
  readonly property var devices: available ? adapter.devices.values : []
  readonly property bool discoverable: available && adapter.discoverable
  readonly property bool discovering: available && adapter.discovering
  property bool discoveryRequested: false
  readonly property bool enabled: available && adapter.enabled
  readonly property var sortedDevices: sortDevices(devices)

  function cleanupCodecData(addr: string): void {
    if (!addr)
      return;
    delete deviceCodecs[addr];
    delete deviceAvailableCodecs[addr];
    deviceCodecsChanged();
    deviceAvailableCodecsChanged();
  }

  function connectDevice(device: QtObject): void {
    if (!device)
      return;
    device.trusted = true;
    device.connect();
  }

  function disconnectDevice(device: QtObject): void {
    if (!device)
      return;
    device.disconnect();
    cleanupCodecData(device.address);
  }

  function fetchCodecs(device: QtObject, fullScan = true): void {
    if (!device?.connected || !isAudioDevice(device) || codecParser.running)
      return;
    codecParser.addr = device.address;
    codecParser.cardName = `bluez_card.${device.address.replace(/:/g, "_")}`;
    codecParser.fullScan = fullScan;
    codecParser.running = true;
  }

  function forgetDevice(device: QtObject): void {
    if (!device)
      return;
    device.trusted = false;
    device.forget();
    cleanupCodecData(device.address);
  }

  function getBattery(device: QtObject): string {
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

  function getDeviceIcon(device: QtObject): string {
    if (!device)
      return "󰂯";
    const name = (device.name || device.deviceName || "").toLowerCase();
    const icon = (device.icon || "").toLowerCase();
    for (const [keywords, glyph] of deviceIconMap) {
      if (keywords.some(k => icon.includes(k) || name.includes(k)))
        return glyph;
    }
    return "󰂯";
  }

  function getDeviceName(device: QtObject): string {
    return device?.name || device?.deviceName || "";
  }

  function getStatusString(device: QtObject): string {
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

  function isAudioDevice(device: QtObject): bool {
    if (!device)
      return false;
    const name = (device.name || device.deviceName || "").toLowerCase();
    const icon = (device.icon || "").toLowerCase();
    return audioKeywords.some(k => icon.includes(k) || name.includes(k));
  }

  function isDeviceBusy(device: QtObject): bool {
    return device?.pairing || device?.state === BluetoothDeviceState.Disconnecting || device?.state === BluetoothDeviceState.Connecting;
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
    if (line.includes("codec") && line.includes("available: yes")) {
      const parts = line.split(": ");
      if (parts.length < 2)
        return;
      const profile = parts[0].trim();
      const match = parts[1].match(/codec ([^\)\s]+)/i);
      const raw = match ? match[1].toUpperCase() : "UNKNOWN";
      const info = getCodecInfo(raw);
      if (!codecParser.parsedCodecs.some(c => c.profile === profile)) {
        codecParser.parsedCodecs.push({
          name: info.name,
          profile,
          description: info.desc,
          qualityColor: info.color
        });
      }
    }
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
    Qt.callLater(() => adapter.enabled = false);
  }

  function sortDevices(list: var): var {
    if (!list?.length)
      return [];
    return [...list].sort((a, b) => {
      if (a.connected !== b.connected)
        return b.connected - a.connected;
      const aPaired = a.paired || a.trusted;
      const bPaired = b.paired || b.trusted;
      if (aPaired !== bPaired)
        return bPaired - aPaired;
      const aName = getDeviceName(a);
      const bName = getDeviceName(b);
      return aName.localeCompare(bName);
    });
  }

  function startDiscovery(): void {
    Logger.log("BluetoothService", `Start discovery (enabled=${adapter?.enabled ?? false})`);
    discoveryRequested = true;
    if (adapter?.enabled)
      adapter.discovering = true;
  }

  function stopDiscovery(): void {
    Logger.log("BluetoothService", `Stop discovery requested`);
    discoveryRequested = false;
  }

  function switchCodec(device: QtObject, profile: string): void {
    if (!device?.address || codecSwitch.running)
      return;
    codecSwitch.cardName = `bluez_card.${device.address.replace(/:/g, "_")}`;
    codecSwitch.profile = profile;
    codecSwitch.deviceAddress = device.address;
    codecSwitch.running = true;
  }

  Component.onCompleted: Logger.log("BluetoothService", `Init: defaultAdapter=${Bluetooth.defaultAdapter ? "yes" : "no"}`)
  Component.onDestruction: {
    codecParser.running = false;
    codecSwitch.running = false;
  }

  Connections {
    function onDiscoveringChanged() {
      Logger.log("BluetoothService", `Adapter discovering changed: ${root.adapter?.discovering ?? false}`);
    }

    function onEnabledChanged() {
      Logger.log("BluetoothService", `Adapter enabled changed: ${root.adapter?.enabled ?? false}`);
    }

    target: root.adapter
  }

  Connections {
    function onDefaultAdapterChanged() {
      const adapter = Bluetooth.defaultAdapter;
      Logger.log("BluetoothService", `Default adapter changed: ${adapter ? "set" : "none"}`);
    }

    target: Bluetooth
  }

  Process {
    id: codecParser

    property string activeProfile: ""
    property string addr: ""
    property string cardName: ""
    property bool fullScan: true
    property bool inCard: false
    property var parsedCodecs: []

    command: ["pactl", "list", "cards"]

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: data => root.parseCodecLine(data.trim())
    }

    onRunningChanged: {
      if (running) {
        parsedCodecs = [];
        activeProfile = "";
        inCard = false;
      } else if (addr) {
        if (fullScan) {
          root.deviceAvailableCodecs[addr] = parsedCodecs;
          root.deviceAvailableCodecsChanged();
        }
        const hit = parsedCodecs.find(c => c.profile === activeProfile);
        if (hit) {
          root.deviceCodecs[addr] = hit.name;
          root.deviceCodecsChanged();
        }
        addr = "";
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
        const device = root.adapter?.devices?.get(deviceAddress);
        if (device)
          Qt.callLater(() => root.fetchCodecs(device, false));
        deviceAddress = "";
        cardName = "";
        profile = "";
      }
    }
  }
}
