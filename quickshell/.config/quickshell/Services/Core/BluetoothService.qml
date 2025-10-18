pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

Singleton {
  id: root

  readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
  readonly property var allDevicesWithBattery: devices.filter(d => d?.batteryAvailable && d?.battery > 0)
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
  readonly property var deviceIconChecks: [[["display", "tv", "[tv]", "television"], "󰔂"], [["watch"], "󰥔"], [["mouse"], "󰍽"], [["keyboard"], "󰌌"], [phoneKeywords, "󰄜"], [audioKeywords, "󰋋"]]
  readonly property var devices: available ? adapter.devices.values : []
  readonly property bool discoverable: available && adapter.discoverable
  readonly property bool discovering: available && adapter.discovering
  readonly property bool enabled: available && adapter.enabled
  readonly property var pairedDevices: devices.filter(d => d?.paired || d?.trusted)
  readonly property var phoneKeywords: ["phone", "iphone", "android", "samsung"]
  readonly property var signalStrengthMap: ({
      excellent: {
        name: "Excellent",
        icon: "󰤟"
      },
      good: {
        name: "Good",
        icon: "󰤞"
      },
      fair: {
        name: "Fair",
        icon: "󰤟"
      },
      poor: {
        name: "Poor",
        icon: "󰤜"
      },
      unknown: {
        name: "Unknown",
        icon: "󰤟"
      }
    })

  function canConnect(device) {
    return !device.connected && !isDeviceBusy(device) && !device.blocked;
  }

  function canDisconnect(device) {
    return device.connected && !isDeviceBusy(device);
  }

  function cleanupDeviceCodecData(addr) {
    delete deviceCodecs[addr];
    delete deviceAvailableCodecs[addr];
    deviceCodecsChanged();
    deviceAvailableCodecsChanged();
  }

  function connectDeviceWithTrust(device) {
    device.trusted = true;
    device.connect();
  }

  function disconnectDevice(device) {
    device.disconnect();
    if (device.address)
      cleanupDeviceCodecData(device.address);
  }

  function forgetDevice(device) {
    device.trusted = false;
    device.forget();
    if (device.address)
      cleanupDeviceCodecData(device.address);
  }

  function getAvailableCodecs(d) {
    if (!d?.connected || !isAudioDevice(d) || codecParser.running)
      return;

    const card = getCardName(d);
    codecParser.cardName = card;
    codecParser.addr = d.address;
    codecParser.fullScan = true;
    codecParser.running = true;
  }

  function getBattery(device) {
    return `${Math.round((device?.battery ?? 0) * 100)}%`;
  }

  function getCardName(d) {
    return d?.address ? `bluez_card.${d.address.replace(/:/g, "_")}` : "";
  }

  function getCodecInfo(n) {
    const k = (n || "").replace(/-/g, "_").toUpperCase();
    return codecMap[k] ?? {
      name: n || "",
      desc: "Unknown",
      color: "#9E9E9E"
    };
  }

  function getDeviceIcon(device) {
    if (!device)
      return "󰂯";
    const name = getDeviceName(device).toLowerCase();
    const icon = (device.icon || "").toLowerCase();

    for (const [keywords, glyph] of deviceIconChecks) {
      if (keywords.some(k => icon.includes(k) || name.includes(k)))
        return glyph;
    }
    return "󰂯";
  }

  function getDeviceName(device) {
    return device?.name || device?.deviceName || "";
  }

  function getSignalCategory(device) {
    const signal = device?.signalStrength || 0;
    if (signal >= 80)
      return "excellent";
    if (signal >= 60)
      return "good";
    if (signal >= 40)
      return "fair";
    if (signal >= 20)
      return "poor";
    return "unknown";
  }

  function getSignalIcon(device) {
    return signalStrengthMap[getSignalCategory(device)].icon;
  }

  function getSignalStrength(device) {
    return signalStrengthMap[getSignalCategory(device)].name;
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

  function isAudioDevice(d) {
    if (!d)
      return false;
    const name = getDeviceName(d).toLowerCase();
    const icon = (d.icon || "").toLowerCase();
    return audioKeywords.some(k => icon.includes(k) || name.includes(k));
  }

  function isDeviceBusy(device) {
    return device?.pairing || device?.state === BluetoothDeviceState.Disconnecting || device?.state === BluetoothDeviceState.Connecting;
  }

  function refreshDeviceCodec(d) {
    if (!d?.connected || !isAudioDevice(d) || codecParser.running)
      return;

    const card = getCardName(d);
    codecParser.cardName = card;
    codecParser.addr = d.address;
    codecParser.fullScan = false;
    codecParser.running = true;
  }

  function setBluetoothEnabled(enabled) {
    if (adapter)
      adapter.enabled = enabled;
  }

  function setDiscoverable(discoverable) {
    if (adapter)
      adapter.discoverable = discoverable;
  }

  function sortDevices(list) {
    if (!list)
      return [];
    return list.slice().sort((a, b) => {
      const aConnected = a?.connected || false;
      const bConnected = b?.connected || false;
      if (aConnected !== bConnected)
        return bConnected - aConnected;

      const aPaired = a?.paired || a?.trusted || false;
      const bPaired = b?.paired || b?.trusted || false;
      if (aPaired !== bPaired)
        return bPaired - aPaired;

      const aName = getDeviceName(a);
      const bName = getDeviceName(b);
      const aHasRealName = aName.includes(" ") && aName.length > 3;
      const bHasRealName = bName.includes(" ") && bName.length > 3;
      if (aHasRealName !== bHasRealName)
        return bHasRealName - aHasRealName;

      return aName.localeCompare(bName);
    });
  }

  function startDiscovery() {
    if (adapter && adapter.enabled)
      adapter.discovering = true;
  }

  function stopDiscovery() {
    if (adapter)
      adapter.discovering = false;
  }

  function switchCodec(d, profile) {
    if (!d || !isAudioDevice(d) || codecSwitch.running)
      return;

    const card = getCardName(d);
    codecSwitch.cardName = card;
    codecSwitch.profile = profile;
    codecSwitch.deviceAddress = d.address || "";
    codecSwitch.running = true;
  }

  function updateAvailableCodecs(addr, list) {
    deviceAvailableCodecs[addr] = list;
    deviceAvailableCodecsChanged();
  }

  function updateDeviceCodec(addr, codec) {
    deviceCodecs[addr] = codec;
    deviceCodecsChanged();
  }

  Component.onDestruction: {
    if (codecParser.running)
      codecParser.running = false;
    if (codecSwitch.running)
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

    property string addr: ""
    property var available: []
    property string cardName: ""
    property string detected: ""
    property bool fullScan: false
    property bool seen: false

    function reset() {
      addr = "";
      cardName = "";
      seen = false;
      detected = "";
      available = [];
      fullScan = false;
    }

    command: ["pactl", "list", "cards"]

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: data => {
        const line = data.trim();
        if (line.includes(`Name: ${codecParser.cardName}`)) {
          codecParser.seen = true;
          return;
        }
        if (codecParser.seen && line.startsWith("Name: ") && !line.includes(codecParser.cardName)) {
          codecParser.seen = false;
          return;
        }
        if (!codecParser.seen)
          return;

        if (line.startsWith("Active Profile:")) {
          const p = line.split(": ")[1] || "";
          const hit = codecParser.available.find(c => c.profile === p);
          if (hit)
            codecParser.detected = hit.name;
          return;
        }

        if (line.includes("codec") && line.includes("available: yes")) {
          const parts = line.split(": ");
          if (parts.length < 2)
            return;
          const profile = parts[0].trim();
          const desc = parts[1];
          const m = desc.match(/codec ([^\)\s]+)/i);
          const raw = m ? m[1].toUpperCase() : "UNKNOWN";
          const info = root.getCodecInfo(raw);

          if (!codecParser.available.some(c => c.profile === profile)) {
            codecParser.available = [...codecParser.available,
              {
                name: info.name,
                profile,
                description: info.desc,
                qualityColor: info.color
              }
            ];
          }
        }
      }
    }

    onRunningChanged: {
      if (!running && addr) {
        if (fullScan) {
          root.updateAvailableCodecs(addr, available);
          root.updateDeviceCodec(addr, detected);
        } else {
          root.updateDeviceCodec(addr, detected);
        }
        reset();
      }
    }
  }

  Process {
    id: codecSwitch

    property string cardName: ""
    property string deviceAddress: ""
    property string profile: ""

    function reset() {
      cardName = "";
      profile = "";
      deviceAddress = "";
    }

    command: ["pactl", "set-card-profile", cardName, profile]

    onRunningChanged: {
      if (!running && deviceAddress) {
        const device = root.adapter?.devices?.get(deviceAddress);
        if (device)
          Qt.callLater(() => root.refreshDeviceCodec(device));
        reset();
      }
    }
  }
}
