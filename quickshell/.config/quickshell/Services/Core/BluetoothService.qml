pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

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
  property var deviceAvailableCodecs: ({})
  property var deviceCodecs: ({})
  readonly property var deviceIconMap: [[["display", "tv", "[tv]", "television"], "󰔂"], [["watch"], "󰥔"], [["mouse"], "󰍽"], [["keyboard"], "󰌌"], [["phone", "iphone", "android", "samsung"], "󰄜"], [audioKeywords, "󰋋"]]
  readonly property var devices: available ? adapter.devices.values : []
  readonly property bool discoverable: available && adapter.discoverable
  readonly property bool discovering: available && adapter.discovering
  readonly property bool enabled: available && adapter.enabled
  readonly property var sortedDevices: sortDevices(devices)

  function canConnect(device) {
    return device && !device.connected && !isDeviceBusy(device) && !device.blocked;
  }

  function canDisconnect(device) {
    return device && device.connected && !isDeviceBusy(device);
  }

  function cleanupCodecData(addr) {
    if (!addr)
      return;
    delete deviceCodecs[addr];
    delete deviceAvailableCodecs[addr];
    deviceCodecsChanged();
    deviceAvailableCodecsChanged();
  }

  function connectDevice(device) {
    if (!device)
      return;
    device.trusted = true;
    device.connect();
  }

  function disconnectDevice(device) {
    if (!device)
      return;
    device.disconnect();
    cleanupCodecData(device.address);
  }

  function fetchCodecs(device, fullScan = true) {
    if (!device?.connected || !isAudioDevice(device) || codecParser.running)
      return;
    codecParser.addr = device.address;
    codecParser.cardName = `bluez_card.${device.address.replace(/:/g, "_")}`;
    codecParser.fullScan = fullScan;
    codecParser.running = true;
  }

  function forgetDevice(device) {
    if (!device)
      return;
    device.trusted = false;
    device.forget();
    cleanupCodecData(device.address);
  }

  function getBattery(device) {
    return device?.batteryAvailable && device.battery > 0 ? `${Math.round(device.battery * 100)}%` : "";
  }

  function getCodecInfo(name) {
    const key = (name || "").replace(/-/g, "_").toUpperCase();
    return codecMap[key] ?? {
      name: name || "",
      desc: "Unknown",
      color: "#9E9E9E"
    };
  }

  function getDeviceIcon(device) {
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

  function getDeviceName(device) {
    return device?.name || device?.deviceName || "";
  }

  function getStatusString(device) {
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

  function isAudioDevice(device) {
    if (!device)
      return false;
    const name = (device.name || device.deviceName || "").toLowerCase();
    const icon = (device.icon || "").toLowerCase();
    return audioKeywords.some(k => icon.includes(k) || name.includes(k));
  }

  function isDeviceBusy(device) {
    return device?.pairing || device?.state === BluetoothDeviceState.Disconnecting || device?.state === BluetoothDeviceState.Connecting;
  }

  function setDiscoverable(value) {
    if (adapter)
      adapter.discoverable = value;
  }

  function setEnabled(value) {
    if (adapter)
      adapter.enabled = value;
  }

  function sortDevices(list) {
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
      const aReal = aName.includes(" ") && aName.length > 3;
      const bReal = bName.includes(" ") && bName.length > 3;
      if (aReal !== bReal)
        return bReal - aReal;
      return aName.localeCompare(bName);
    });
  }

  function startDiscovery() {
    if (adapter?.enabled)
      adapter.discovering = true;
  }

  function stopDiscovery() {
    if (adapter)
      adapter.discovering = false;
  }

  function switchCodec(device, profile) {
    if (!device?.address || codecSwitch.running)
      return;
    codecSwitch.cardName = `bluez_card.${device.address.replace(/:/g, "_")}`;
    codecSwitch.profile = profile;
    codecSwitch.deviceAddress = device.address;
    codecSwitch.running = true;
  }

  Component.onDestruction: {
    codecParser.running = false;
    codecSwitch.running = false;
  }

  Connections {
    function onEnabledChanged() {
      if (root.adapter?.enabled)
        Qt.callLater(() => root.adapter.discovering = true);
    }

    target: root.adapter
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

      onRead: data => {
        const line = data.trim();
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
          const info = root.getCodecInfo(raw);
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
