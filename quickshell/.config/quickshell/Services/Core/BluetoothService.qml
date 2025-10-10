pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

Singleton {
  id: root

  property var adapter: null
  readonly property bool available: adapter !== null
  readonly property bool enabled: adapter?.enabled ?? false
  readonly property bool discovering: adapter?.discovering ?? false
  readonly property bool discoverable: adapter?.discoverable ?? false
  readonly property var devices: adapter?.devices?.values ?? []
  readonly property var pairedDevices: devices.filter(d => d?.paired || d?.trusted)

  property var deviceCodecs: ({})
  property var deviceAvailableCodecs: ({})

  readonly property var audioKeywords: ["headset", "audio", "headphone", "airpod", "arctis"]
  readonly property var phoneKeywords: ["phone", "iphone", "android", "samsung"]

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

  function setAdapter(a) {
    adapter = a;
  }

  function getDeviceName(device) {
    return device?.name || device?.deviceName || "";
  }

  function sortDevices(list) {
    if (!list)
      return [];
    return list.slice().sort((a, b) => {
      // Priority 1: Connected devices first
      const aConnected = a?.connected || false;
      const bConnected = b?.connected || false;
      if (aConnected && !bConnected)
        return -1;
      if (!aConnected && bConnected)
        return 1;

      // Priority 2: Paired/trusted devices
      const aPaired = a?.paired || a?.trusted || false;
      const bPaired = b?.paired || b?.trusted || false;
      if (aPaired && !bPaired)
        return -1;
      if (!aPaired && bPaired)
        return 1;

      // Priority 3: Devices with real names
      const aName = getDeviceName(a);
      const bName = getDeviceName(b);
      const aHasRealName = aName.includes(" ") && aName.length > 3;
      const bHasRealName = bName.includes(" ") && bName.length > 3;
      if (aHasRealName && !bHasRealName)
        return -1;
      if (!aHasRealName && bHasRealName)
        return 1;

      // Priority 4: Alphabetical by name
      return aName.localeCompare(bName);
    });
  }

  function getDeviceIcon(device) {
    if (!device)
      return "󰂯";
    const name = getDeviceName(device).toLowerCase();
    const icon = (device.icon || "").toLowerCase();

    // Check specific device types first (more specific to less specific)
    if (icon.includes("display") || icon.includes("tv") || name.includes("[tv]") || name.includes("television"))
      return "󰔂";
    if (icon.includes("watch") || name.includes("watch"))
      return "󰥔";
    if (icon.includes("mouse") || name.includes("mouse"))
      return "󰍽";
    if (icon.includes("keyboard") || name.includes("keyboard"))
      return "󰌌";
    if (phoneKeywords.some(k => icon.includes(k) || name.includes(k)))
      return "󰄜";
    if (icon.includes("speaker") || name.includes("speaker"))
      return "󰓃";
    if (audioKeywords.some(k => icon.includes(k) || name.includes(k)))
      return "󰋋";
    return "󰂯";
  }

  function isDeviceBusy(device) {
    return device?.pairing || device?.state === BluetoothDeviceState.Disconnecting || device?.state === BluetoothDeviceState.Connecting;
  }

  function canConnect(device) {
    return !device?.connected && !device?.pairing && !device?.blocked;
  }

  function canDisconnect(device) {
    return device?.connected && !device?.pairing && !device?.blocked;
  }

  function connectDeviceWithTrust(device) {
    if (!device)
      return;
    device.trusted = true;
    device.connect();
  }

  function disconnectDevice(device) {
    device?.disconnect();
    // Cleanup codec data on disconnect
    if (device?.address) {
      cleanupDeviceCodecData(device.address);
    }
  }

  function forgetDevice(device) {
    if (!device)
      return;
    device.trusted = false;
    device.forget();
    // Cleanup codec data to prevent memory leak
    if (device.address) {
      cleanupDeviceCodecData(device.address);
    }
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

  function setBluetoothEnabled(enabled) {
    if (adapter)
      adapter.enabled = enabled;
  }

  function setDiscoverable(discoverable) {
    if (adapter)
      adapter.discoverable = discoverable;
  }

  function startDiscovery() {
    if (adapter && adapter.enabled)
      adapter.discovering = true;
  }

  function stopDiscovery() {
    if (adapter)
      adapter.discovering = false;
  }

  function getCardName(d) {
    return d?.address ? `bluez_card.${d.address.replace(/:/g, "_")}` : "";
  }

  function isAudioDevice(d) {
    if (!d)
      return false;
    const name = getDeviceName(d).toLowerCase();
    const icon = (d.icon || "").toLowerCase();

    return audioKeywords.some(k => icon.includes(k) || name.includes(k)) || icon.includes("speaker") || name.includes("speaker");
  }

  function getCodecInfo(n) {
    const k = (n || "").replace(/-/g, "_").toUpperCase();
    return codecMap[k] ?? {
      name: n || "",
      desc: "Unknown",
      color: "#9E9E9E"
    };
  }

  function updateDeviceCodec(addr, codec) {
    deviceCodecs = Object.assign({}, deviceCodecs, {
      [addr]: codec
    });
  }

  function updateAvailableCodecs(addr, list) {
    deviceAvailableCodecs = Object.assign({}, deviceAvailableCodecs, {
      [addr]: list
    });
  }

  function cleanupDeviceCodecData(addr) {
    const newCodecs = Object.assign({}, deviceCodecs);
    const newAvailable = Object.assign({}, deviceAvailableCodecs);
    delete newCodecs[addr];
    delete newAvailable[addr];
    deviceCodecs = newCodecs;
    deviceAvailableCodecs = newAvailable;
  }

  function refreshDeviceCodec(d) {
    if (!d?.connected || !isAudioDevice(d))
      return;

    // Don't start a new process if one is already running
    if (codecParser.running) {
      console.warn("BluetoothService: codecParser already running, skipping refresh");
      return;
    }

    const card = getCardName(d);
    codecParser.cardName = card;
    codecParser.addr = d.address;
    codecParser.available = [];
    codecParser.seen = false;
    codecParser.detected = "";
    codecParser.fullScan = false;
    codecParser.running = true;
  }

  function getAvailableCodecs(d) {
    if (!d?.connected || !isAudioDevice(d))
      return;

    // Don't start a new process if one is already running
    if (codecParser.running) {
      console.warn("BluetoothService: codecParser already running, skipping codec query");
      return;
    }

    const card = getCardName(d);
    codecParser.cardName = card;
    codecParser.addr = d.address;
    codecParser.available = [];
    codecParser.seen = false;
    codecParser.detected = "";
    codecParser.fullScan = true;
    codecParser.running = true;
  }

  function switchCodec(d, profile) {
    if (!d || !isAudioDevice(d))
      return;

    // Don't start if already running
    if (codecSwitch.running) {
      console.warn("BluetoothService: codecSwitch already running");
      return;
    }

    const card = getCardName(d);
    codecSwitch.cardName = card;
    codecSwitch.profile = profile;
    codecSwitch.deviceAddress = d.address || "";
    codecSwitch.running = true;
  }

  Process {
    id: codecParser
    property string cardName: ""
    property string addr: ""
    property bool seen: false
    property string detected: ""
    property var available: []
    property bool fullScan: false

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
        if (fullScan)
          root.updateAvailableCodecs(addr, available);
        else
          root.updateDeviceCodec(addr, detected);

        addr = "";
        cardName = "";
        seen = false;
        detected = "";
        available = [];
        fullScan = false;
      }
    }
  }

  Process {
    id: codecSwitch
    property string cardName: ""
    property string profile: ""
    property string deviceAddress: ""

    command: ["pactl", "set-card-profile", cardName, profile]
    onRunningChanged: {
      if (!running && deviceAddress) {
        // Only refresh the specific device that was switched
        const device = root.adapter?.devices?.get(deviceAddress);
        if (device) {
          Qt.callLater(() => root.refreshDeviceCodec(device));
        }
        cardName = "";
        profile = "";
        deviceAddress = "";
      }
    }
  }

  Component.onDestruction: {
    if (codecParser.running)
      codecParser.running = false;
    if (codecSwitch.running)
      codecSwitch.running = false;
  }
}
