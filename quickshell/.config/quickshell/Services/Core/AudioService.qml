pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Services.Utils

Singleton {
  id: root

  // Icon mapping for devices
  readonly property var _deviceIconMap: ({
      "headphone": "󰋋",
      "hands-free": "󰋎",
      "headset": "󰋎",
      "phone": "󰏲",
      "portable": "󰏲"
    })
  property bool _muted: !!(root.sink && root.sink.audio && root.sink.audio.muted)
  property real _volume: {
    var vol = (root.sink && root.sink.audio ? root.sink.audio.volume : 0);
    if (!Number.isFinite(vol) || vol < 0)
      vol = 0;
    return vol;
  }
  // Volume policy
  readonly property real maxVolume: 1.5            // absolute max (1.0 == 100%)
  readonly property int maxVolumePercent: Math.round(maxVolume * 100)      // display/IPC cap in percent
  readonly property alias muted: root._muted
  // Properties — lists of sinks/sources (exclude streams)
  readonly property PwNode sink: Pipewire.defaultAudioSink

  // Expose the current sink icon for UI widgets
  readonly property string sinkIcon: deviceIconFor(root.sink)
  readonly property list<PwNode> sinks: Pipewire.nodes.values.filter(n => !n.isStream && n.isSink)
  readonly property PwNode source: Pipewire.defaultAudioSource
  readonly property list<PwNode> sources: Pipewire.nodes.values.filter(n => !n.isStream && !n.isSink && n.audio)

  // Step amount for increase/decrease helpers (0..1)
  readonly property real stepVolume: 0.05
  // Reactive exposed state (0..maxVolume) with private mirrors
  readonly property alias volume: root._volume

  // Signals
  signal micMuteChanged

  // Helper: sanitize a raw volume value from backend into [0..maxVolume]
  function _sanitizeVolume(v) {
    var out = Number.isFinite(v) ? v : 0;
    if (out < 0)
      out = 0;
    if (out > root.maxVolume)
      out = root.maxVolume;
    return out;
  }

  // Internal: stable key for a node and helpers to map/diff
  function _nodeKey(node) {
    if (!node)
      return "";
    // Prefer explicit id if available, fallback to name
    if (node.id !== undefined && node.id !== null)
      return String(node.id);
    if (node.name)
      return String(node.name);
    const props = node.properties || {};
    if (props["node.name"])
      return String(props["node.name"]);
    return String(root.displayName(node));
  }
  function decreaseVolume() {
    setVolumeReal(root.volume - root.stepVolume);
  }
  function deviceIconFor(node) {
    if (!node)
      return "";
    const props = node.properties || {};
    const iconName = props["device.icon_name"] || "";
    if (root._deviceIconMap[iconName])
      return root._deviceIconMap[iconName];

    const desc = (node.description || "").toLowerCase();
    for (var key in root._deviceIconMap)
      if (desc.indexOf(key) !== -1)
        return root._deviceIconMap[key];

    return (node.name || "").startsWith("bluez_output") ? root._deviceIconMap["headphone"] : "";
  }

  // Functions — Human-friendly device naming
  function displayName(node) {
    if (!node)
      return "";

    const props = node.properties || {};
    const deviceDesc = props["device.description"];
    if (deviceDesc)
      return deviceDesc;

    const description = node.description ?? "";
    const nickname = node.nickname ?? "";
    const name = node.name ?? "";

    if (description && description !== name)
      return description;
    if (nickname && nickname !== name)
      return nickname;

    const lname = String(name).toLowerCase();
    if (lname.includes("analog-stereo"))
      return "Built-in Speakers";
    if (lname.includes("bluez"))
      return "Bluetooth Audio";
    if (lname.includes("usb"))
      return "USB Audio";
    if (lname.includes("hdmi"))
      return "HDMI Audio";

    return name;
  }
  function increaseVolume() {
    setVolumeReal(root.volume + root.stepVolume);
  }

  // Default device switching
  function setAudioSink(newSink) {
    Logger.log("AudioService", "setAudioSink:", root.displayName(newSink));
    Pipewire.preferredDefaultAudioSink = newSink;
  }
  function setAudioSource(newSource) {
    Logger.log("AudioService", "setAudioSource:", root.displayName(newSource));
    Pipewire.preferredDefaultAudioSource = newSource;
  }
  function setMicVolume(percentage) {
    const n = Number.parseInt(percentage, 10);
    if (Number.isNaN(n))
      return "Invalid percentage";
    if (root.source && root.source.audio) {
      const clamped = Math.max(0, Math.min(100, n));
      Logger.log("AudioService", "setMicVolume:", clamped + "%");
      root.source.audio.volume = clamped / 100;
      root.micMuteChanged();
      return "Microphone volume set to " + clamped + "%";
    }
    return "No audio source available";
  }
  function setMuted(muted) {
    if (root.sink && root.sink.audio && root.sink.ready) {
      Logger.log("AudioService", "setMuted:", !!muted);
      root.sink.audio.muted = !!muted;
    }
  }

  // Volume control helpers (percentage-based API retained for IPC)
  function setVolume(percentage) {
    const n = Number.parseInt(percentage, 10);
    if (Number.isNaN(n))
      return "Invalid percentage";
    if (root.sink && root.sink.audio) {
      const clamped = Math.max(0, Math.min(root.maxVolumePercent, n));
      Logger.log("AudioService", "setVolume request:", clamped + "%");
      setVolumeReal(clamped / 100);
      return "Volume set to " + clamped + "%";
    }
    return "No audio sink available";
  }

  // Real volume setter (0..1)
  function setVolumeReal(newVolume) {
    if (root.sink && root.sink.audio && root.sink.ready) {
      const nv = Number.isFinite(newVolume) ? newVolume : 0;
      const clamped = Math.max(0, Math.min(root.maxVolume, nv));
      Logger.log("AudioService", "setVolumeReal:", Math.round(clamped * 100) + "%");
      root.sink.audio.muted = false;
      root.sink.audio.volume = clamped;
      // _volume is updated via Connections
    }
  }
  function toggleMicMute() {
    if (root.source && root.source.audio) {
      root.source.audio.muted = !root.source.audio.muted;
      Logger.log("AudioService", "toggleMicMute ->", root.source.audio.muted ? "muted" : "unmuted");
      root.micMuteChanged();
      return root.source.audio.muted ? "Microphone muted" : "Microphone unmuted";
    }
    return "No audio source available";
  }
  function toggleMute() {
    if (root.sink && root.sink.audio) {
      const next = !root.sink.audio.muted;
      Logger.log("AudioService", "toggleMute ->", next ? "muted" : "unmuted");
      setMuted(next);
      return next ? "Audio muted" : "Audio unmuted";
    }
    return "No audio sink available";
  }

  // Lifecycle
  Component.onCompleted: {
    const initVol = _sanitizeVolume(root.sink && root.sink.audio ? root.sink.audio.volume : 0);
    Logger.log("AudioService", "ready; default sink=", root.displayName(root.sink), "muted=", !!(root.sink && root.sink.audio && root.sink.audio.muted), "volume=", Math.round(initVol * 100) + "%", "default source=", root.displayName(root.source));
  }

  // Also update/emit when default devices flip
  onSinkChanged: {
    var vol = (root.sink && root.sink.audio ? root.sink.audio.volume : 0);
    if (!Number.isFinite(vol) || vol < 0)
      vol = 0;
    // Clamp to policy immediately on sink switch as well
    if (vol > root.maxVolume && root.sink?.ready && root.sink?.audio) {
      Logger.log("AudioService", "volume above policy (", Math.round(vol * 100), "%) on sink change -> clamping to", Math.round(root.maxVolume * 100), "%");
      root.sink.audio.volume = root.maxVolume;
      vol = root.maxVolume;
    }
    root._volume = vol;
    root._muted = !!(root.sink && root.sink.audio && root.sink.audio.muted);
    Logger.log("AudioService", "default sink changed ->", root.displayName(root.sink), "muted=", root._muted, "volume=", Math.round(root._volume * 100) + "%");
  }

  onSourceChanged: {
    Logger.log("AudioService", "default source changed ->", root.displayName(root.source));
    root.micMuteChanged();
  }

  // Objects — trackers, IPC, connections
  PwObjectTracker {
    objects: root.sinks.concat(root.sources)
  }

  // React to underlying audio changes (external mixers, device switches)
  Connections {
    function onMutedChanged() {
      root._muted = !!(root.sink && root.sink.audio && root.sink.audio.muted);
      Logger.log("AudioService", "sink muted changed ->", root._muted);
    }
    function onVolumeChanged() {
      var vol = (root.sink && root.sink.audio ? root.sink.audio.volume : 0);
      if (!Number.isFinite(vol) || vol < 0)
        vol = 0;
      // Clamp externally-set volumes to policy
      if (vol > root.maxVolume && root.sink?.ready && root.sink?.audio) {
        Logger.log("AudioService", "volume above policy (", Math.round(vol * 100), "%) -> clamping to", Math.round(root.maxVolume * 100), "%");
        root.sink.audio.volume = root.maxVolume;
        vol = root.maxVolume;
      }
      root._volume = vol;
      Logger.log("AudioService", "sink volume changed ->", Math.round(vol * 100) + "%");
    }

    target: root.sink && root.sink.audio ? root.sink.audio : null
  }
  Connections {
    function onMutedChanged() {
      Logger.log("AudioService", "mic muted changed ->", !!(root.source && root.source.audio && root.source.audio.muted));
      root.micMuteChanged();
    }
    function onVolumeChanged() {
      var mv = (root.source && root.source.audio ? root.source.audio.volume : 0);
      if (!Number.isFinite(mv) || mv < 0)
        mv = 0;
      Logger.log("AudioService", "mic volume changed ->", Math.round(mv * 100) + "%");
      root.micMuteChanged();
    }

    target: root.source && root.source.audio ? root.source.audio : null
  }
}
