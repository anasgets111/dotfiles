pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// no Utils import needed

Singleton {
  id: root

  // bind directly to default adapter; keep null-safe
  // adapter stored as var; set via Connections to avoid type resolution warnings
  property var adapter: null
  readonly property bool available: adapter !== null
  readonly property bool enabled: (adapter && adapter.enabled) ?? false
  readonly property bool discovering: (adapter && adapter.discovering) ?? false
  // always expose an array for consumers
  readonly property var devices: (adapter && adapter.devices && adapter.devices.values) ? adapter.devices.values : []
  // allow external wiring
  function setAdapter(a) {
    adapter = a;
  }

  readonly property var pairedDevices: {
    if (!devices || devices.length === 0)
      return [];
    return devices.filter(dev => dev && (dev.paired || dev.trusted));
  }

  readonly property var allDevicesWithBattery: {
    if (!devices || devices.length === 0)
      return [];
    return devices.filter(dev => dev && dev.batteryAvailable && dev.battery > 0);
  }

  // codec caches
  property var deviceCodecs: ({})              // address -> active codec name
  property var deviceAvailableCodecs: ({})     // address -> [{ name, profile, description, qualityColor }]

  // compact keyword sets for icon detection
  readonly property var audioKeywords: ["headset", "audio", "headphone", "airpod", "arctis"]
  readonly property var phoneKeywords: ["phone", "iphone", "android", "samsung"]

  function sortDevices(list) {
    if (!list)
      return [];
    // make shallow copy to avoid mutating original
    return list.slice().sort((a, b) => {
      const aName = (a && (a.name || a.deviceName)) || "";
      const bName = (b && (b.name || b.deviceName)) || "";

      const aHasRealName = aName.includes(" ") && aName.length > 3;
      const bHasRealName = bName.includes(" ") && bName.length > 3;
      if (aHasRealName && !bHasRealName)
        return -1;
      if (!aHasRealName && bHasRealName)
        return 1;

      const aSignal = (a && a.signalStrength > 0) ? a.signalStrength : 0;
      const bSignal = (b && b.signalStrength > 0) ? b.signalStrength : 0;
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
    if (!device || device.battery === undefined)
      return "Battery: Unknown";
    return `Battery: ${Math.round(device.battery * 100)}%`;
  }

  function isDeviceBusy(device) {
    if (!device)
      return false;
    return device.pairing || device.state === BluetoothDeviceState.Disconnecting || device.state === BluetoothDeviceState.Connecting;
  }

  function canConnect(device) {
    if (!device)
      return false;
    // check connected not paired: can connect when not currently connected
    return !device.connected && !device.pairing && !device.blocked;
  }

  function canDisconnect(device) {
    if (!device)
      return false;
    return device.connected && !device.pairing && !device.blocked;
  }

  function connectDeviceWithTrust(device) {
    if (!device)
      return;
    device.trusted = true;
    device.connect();
  }

  function disconnectDevice(device) {
    if (!device)
      return;
    device.disconnect();
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

  // --- Audio codec helpers (compact) ---
  function getCardName(d) {
    return d?.address ? `bluez_card.${d.address.replace(/:/g, "_")}` : "";
  }
  function isAudioDevice(d) {
    const i = getDeviceIcon(d);
    return i === "headset" || i === "speaker";
  }
  function getCodecInfo(n) {
    const k = (n || "").replace(/-/g, "_").toUpperCase();
    const M = {
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
    };
    return M[k] || {
      name: n || "",
      desc: "Unknown",
      color: "#9E9E9E"
    };
  }

  function updateDeviceCodec(addr, codec) {
    var m = Object.assign({}, deviceCodecs);
    m[addr] = codec;
    deviceCodecs = m;
  }
  function updateAvailableCodecs(addr, list) {
    var m = Object.assign({}, deviceAvailableCodecs);
    m[addr] = list;
    deviceAvailableCodecs = m;
  }

  function refreshDeviceCodec(d) {
    if (!d?.connected || !isAudioDevice(d))
      return;
    const card = getCardName(d);
    _codecQuery.cardName = card;
    _codecQuery.addr = d.address;
    _codecQuery.available = [];
    _codecQuery.seen = false;
    _codecQuery.detected = "";
    _codecQuery.running = true;
  }

  function getCurrentCodec(d) {
    if (!d?.connected || !isAudioDevice(d)) {
      return;
    }
    const card = getCardName(d);
    _codecQuery.cardName = card;
    _codecQuery.addr = d.address;
    _codecQuery.available = [];
    _codecQuery.seen = false;
    _codecQuery.detected = "";
    _codecQuery.running = true;
  }

  function getAvailableCodecs(d) {
    if (!d?.connected || !isAudioDevice(d)) {
      return;
    }
    const card = getCardName(d);
    _codecFull.cardName = card;
    _codecFull.addr = d.address;
    _codecFull.available = [];
    _codecFull.seen = false;
    _codecFull.detected = "";
    _codecFull.running = true;
  }

  function switchCodec(d, profile) {
    if (!d || !isAudioDevice(d)) {
      return;
    }
    const card = getCardName(d);
    _codecSwitch.cardName = card;
    _codecSwitch.profile = profile;
    _codecSwitch.running = true;
  }

  Process {
    id: _codecQuery
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
        if (line.includes(`Name: ${_codecQuery.cardName}`)) {
          _codecQuery.seen = true;
          return;
        }
        if (_codecQuery.seen && line.startsWith("Name: ") && !line.includes(_codecQuery.cardName)) {
          _codecQuery.seen = false;
          return;
        }
        if (!_codecQuery.seen)
          return;
        if (line.startsWith("Active Profile:")) {
          const p = (line.split(": ")[1] || "");
          const hit = _codecQuery.available.find(c => c.profile === p);
          if (hit)
            _codecQuery.detected = hit.name;
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
          if (!_codecQuery.available.some(c => c.profile === profile)) {
            const next = _codecQuery.available.slice();
            next.push({
              name: info.name,
              profile,
              description: info.desc,
              qualityColor: info.color
            });
            _codecQuery.available = next;
          }
        }
      }
    }
    onRunningChanged: {
      if (!running) {
        if (_codecQuery.addr)
          root.updateDeviceCodec(_codecQuery.addr, _codecQuery.detected);
        _codecQuery.addr = "";
        _codecQuery.cardName = "";
        _codecQuery.seen = false;
        _codecQuery.detected = "";
        _codecQuery.available = [];
      }
    }
  }

  Process {
    id: _codecFull
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
        if (line.includes(`Name: ${_codecFull.cardName}`)) {
          _codecFull.seen = true;
          return;
        }
        if (_codecFull.seen && line.startsWith("Name: ") && !line.includes(_codecFull.cardName)) {
          _codecFull.seen = false;
          return;
        }
        if (!_codecFull.seen)
          return;
        if (line.startsWith("Active Profile:")) {
          const p = (line.split(": ")[1] || "");
          const hit = _codecFull.available.find(c => c.profile === p);
          if (hit)
            _codecFull.detected = hit.name;
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
          if (!_codecFull.available.some(c => c.profile === profile)) {
            const next = _codecFull.available.slice();
            next.push({
              name: info.name,
              profile,
              description: info.desc,
              qualityColor: info.color
            });
            _codecFull.available = next;
          }
        }
      }
    }
    onRunningChanged: {
      if (!running) {
        if (_codecFull.addr)
          root.updateAvailableCodecs(_codecFull.addr, _codecFull.available);
        _codecFull.addr = "";
        _codecFull.cardName = "";
        _codecFull.seen = false;
        _codecFull.detected = "";
        _codecFull.available = [];
      }
    }
  }

  Process {
    id: _codecSwitch
    property string cardName: ""
    property string profile: ""
    command: ["pactl", "set-card-profile", cardName, profile]
    onRunningChanged: {
      if (!running) {
        if (root.adapter && root.adapter.devices) {
          root.adapter.devices.values.forEach(d => {
            if (d && root.getCardName(d) === _codecSwitch.cardName)
              Qt.callLater(() => root.refreshDeviceCodec(d));
          });
        }
        _codecSwitch.cardName = "";
        _codecSwitch.profile = "";
      }
    }
  }
}
