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
  readonly property var devices: adapter?.devices?.values ?? []
  readonly property var pairedDevices: devices.filter(d => d?.paired || d?.trusted)
  readonly property var allDevicesWithBattery: devices.filter(d => d?.batteryAvailable && d.battery > 0)

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

  function sortDevices(list) {
    if (!list)
      return [];
    return list.slice().sort((a, b) => {
      const aName = a?.name || a?.deviceName || "";
      const bName = b?.name || b?.deviceName || "";
      const aHasRealName = aName.includes(" ") && aName.length > 3;
      const bHasRealName = bName.includes(" ") && bName.length > 3;

      if (aHasRealName && !bHasRealName)
        return -1;
      if (!aHasRealName && bHasRealName)
        return 1;

      const aSignal = a?.signalStrength > 0 ? a.signalStrength : 0;
      const bSignal = b?.signalStrength > 0 ? b.signalStrength : 0;
      return bSignal - aSignal;
    });
  }

  function getDeviceIcon(device) {
    if (!device)
      return "bluetooth";
    const name = (device.name || device.deviceName || "").toLowerCase();
    const icon = (device.icon || "").toLowerCase();

    if (audioKeywords.some(k => icon.includes(k) || name.includes(k)))
      return "headset";
    if (icon.includes("mouse") || name.includes("mouse"))
      return "mouse";
    if (icon.includes("keyboard") || name.includes("keyboard"))
      return "keyboard";
    if (phoneKeywords.some(k => icon.includes(k) || name.includes(k)))
      return "smartphone";
    if (icon.includes("watch") || name.includes("watch"))
      return "watch";
    if (icon.includes("speaker") || name.includes("speaker"))
      return "speaker";
    if (icon.includes("display") || name.includes("tv"))
      return "tv";
    return "bluetooth";
  }

  function getSignalIcon(device) {
    const s = device?.signalStrength ?? -1;
    if (s <= 0)
      return "signal_cellular_null";
    if (s >= 80)
      return "signal_cellular_4_bar";
    if (s >= 60)
      return "signal_cellular_3_bar";
    if (s >= 40)
      return "signal_cellular_2_bar";
    if (s >= 20)
      return "signal_cellular_1_bar";
    return "signal_cellular_0_bar";
  }

  function getSignalStrength(device) {
    const s = device?.signalStrength ?? -1;
    if (s <= 0)
      return "Unknown";
    if (s >= 80)
      return "Excellent";
    if (s >= 60)
      return "Good";
    if (s >= 40)
      return "Fair";
    if (s >= 20)
      return "Poor";
    return "Very Poor";
  }

  function getBattery(device) {
    if (!device?.battery)
      return "Battery: Unknown";
    return `Battery: ${Math.round(device.battery * 100)}%`;
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
  }

  function forgetDevice(device) {
    if (!device)
      return;
    device.trusted = false;
    device.forget();
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

  function getCardName(d) {
    return d?.address ? `bluez_card.${d.address.replace(/:/g, "_")}` : "";
  }

  function isAudioDevice(d) {
    const i = getDeviceIcon(d);
    return i === "headset" || i === "speaker";
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
    const m = Object.assign({}, deviceCodecs);
    m[addr] = codec;
    deviceCodecs = m;
  }

  function updateAvailableCodecs(addr, list) {
    const m = Object.assign({}, deviceAvailableCodecs);
    m[addr] = list;
    deviceAvailableCodecs = m;
  }

  function refreshDeviceCodec(d) {
    if (!d?.connected || !isAudioDevice(d))
      return;
    const card = getCardName(d);
    codecQuery.cardName = card;
    codecQuery.addr = d.address;
    codecQuery.available = [];
    codecQuery.seen = false;
    codecQuery.detected = "";
    codecQuery.running = true;
  }

  function getCurrentCodec(d) {
    refreshDeviceCodec(d);
  }

  function getAvailableCodecs(d) {
    if (!d?.connected || !isAudioDevice(d))
      return;
    const card = getCardName(d);
    codecFull.cardName = card;
    codecFull.addr = d.address;
    codecFull.available = [];
    codecFull.seen = false;
    codecFull.detected = "";
    codecFull.running = true;
  }

  function switchCodec(d, profile) {
    if (!d || !isAudioDevice(d))
      return;
    const card = getCardName(d);
    codecSwitch.cardName = card;
    codecSwitch.profile = profile;
    codecSwitch.running = true;
  }

  Process {
    id: codecQuery
    property string cardName: ""
    property string addr: ""
    property bool seen: false
    property string detected: ""
    property var available: []

    command: ["pactl", "list", "cards"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        const line = data.trim();
        if (line.includes(`Name: ${codecQuery.cardName}`)) {
          codecQuery.seen = true;
          return;
        }
        if (codecQuery.seen && line.startsWith("Name: ") && !line.includes(codecQuery.cardName)) {
          codecQuery.seen = false;
          return;
        }
        if (!codecQuery.seen)
          return;

        if (line.startsWith("Active Profile:")) {
          const p = line.split(": ")[1] || "";
          const hit = codecQuery.available.find(c => c.profile === p);
          if (hit)
            codecQuery.detected = hit.name;
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

          if (!codecQuery.available.some(c => c.profile === profile)) {
            const next = codecQuery.available.slice();
            next.push({
              name: info.name,
              profile,
              description: info.desc,
              qualityColor: info.color
            });
            codecQuery.available = next;
          }
        }
      }
    }
    onRunningChanged: {
      if (!running) {
        if (addr)
          root.updateDeviceCodec(addr, detected);
        addr = "";
        cardName = "";
        seen = false;
        detected = "";
        available = [];
      }
    }
  }

  Process {
    id: codecFull
    property string cardName: ""
    property string addr: ""
    property bool seen: false
    property string detected: ""
    property var available: []

    command: ["pactl", "list", "cards"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        const line = data.trim();
        if (line.includes(`Name: ${codecFull.cardName}`)) {
          codecFull.seen = true;
          return;
        }
        if (codecFull.seen && line.startsWith("Name: ") && !line.includes(codecFull.cardName)) {
          codecFull.seen = false;
          return;
        }
        if (!codecFull.seen)
          return;

        if (line.startsWith("Active Profile:")) {
          const p = line.split(": ")[1] || "";
          const hit = codecFull.available.find(c => c.profile === p);
          if (hit)
            codecFull.detected = hit.name;
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

          if (!codecFull.available.some(c => c.profile === profile)) {
            const next = codecFull.available.slice();
            next.push({
              name: info.name,
              profile,
              description: info.desc,
              qualityColor: info.color
            });
            codecFull.available = next;
          }
        }
      }
    }
    onRunningChanged: {
      if (!running) {
        if (addr)
          root.updateAvailableCodecs(addr, available);
        addr = "";
        cardName = "";
        seen = false;
        detected = "";
        available = [];
      }
    }
  }

  Process {
    id: codecSwitch
    property string cardName: ""
    property string profile: ""

    command: ["pactl", "set-card-profile", cardName, profile]
    onRunningChanged: {
      if (!running) {
        if (root.adapter?.devices) {
          root.adapter.devices.values.forEach(d => {
            if (d && root.getCardName(d) === cardName)
              Qt.callLater(() => root.refreshDeviceCodec(d));
          });
        }
        cardName = "";
        profile = "";
      }
    }
  }

  Component.onDestruction: {
    try {
      codecQuery.running = false;
    } catch (_) {}
    try {
      codecFull.running = false;
    } catch (_) {}
    try {
      codecSwitch.running = false;
    } catch (_) {}
  }
}
