pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Services.Utils

Singleton {
  id: root

  readonly property var deviceIconMap: ({
      "headphone": "󰋋",
      "hands-free": "󰋎",
      "headset": "󰋎",
      "phone": "󰏲",
      "portable": "󰏲"
    })
  readonly property real maxVolume: 1.5
  readonly property int maxVolumePercent: Math.round(maxVolume * 100)
  readonly property bool muted: sink?.audio?.muted ?? false
  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property string sinkIcon: deviceIconFor(sink)
  readonly property list<PwNode> sinks: Pipewire.nodes.values.filter(n => !n.isStream && n.isSink)
  readonly property PwNode source: Pipewire.defaultAudioSource
  readonly property list<PwNode> sources: Pipewire.nodes.values.filter(n => !n.isStream && !n.isSink && n.audio)
  readonly property real stepVolume: 0.05
  readonly property list<PwNode> streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio)
  readonly property real volume: {
    const vol = sink?.audio?.volume ?? 0;
    return Math.max(0, Number.isFinite(vol) ? vol : 0);
  }

  signal micMuteChanged
  signal sinkDeviceChanged(string deviceName, string icon)

  function clampVolume(vol) {
    return Math.max(0, Math.min(maxVolume, Number.isFinite(vol) ? vol : 0));
  }

  function decreaseVolume() {
    setVolumeReal(root.volume - root.stepVolume);
  }

  function deviceIconFor(node) {
    if (!node)
      return "";

    const props = node.properties ?? {};
    const iconName = props["device.icon_name"] ?? "";
    if (deviceIconMap[iconName])
      return deviceIconMap[iconName];

    const desc = (node.description ?? "").toLowerCase();
    for (const key in deviceIconMap)
      if (desc.includes(key))
        return deviceIconMap[key];

    return node.name?.startsWith("bluez_output") ? deviceIconMap["headphone"] : "";
  }

  function displayName(node) {
    if (!node)
      return "";

    const props = node.properties ?? {};
    if (props["device.description"])
      return props["device.description"];

    const desc = node.description ?? "";
    const nick = node.nickname ?? "";
    const name = node.name ?? "";

    if (desc && desc !== name)
      return desc;
    if (nick && nick !== name)
      return nick;

    const lname = name.toLowerCase();
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

  function setAudioSink(newSink) {
    Pipewire.preferredDefaultAudioSink = newSink;
  }

  function setAudioSource(newSource) {
    Pipewire.preferredDefaultAudioSource = newSource;
  }

  function setMicVolume(percentage) {
    const n = Number.parseInt(percentage, 10);
    if (Number.isNaN(n))
      return "Invalid percentage";
    if (!source?.audio)
      return "No audio source available";

    const clamped = Math.max(0, Math.min(100, n));
    source.audio.volume = clamped / 100;
    micMuteChanged();
    return `Microphone volume set to ${clamped}%`;
  }

  function setMuted(muted) {
    if (root.sink?.audio)
      root.sink.audio.muted = !!muted;
  }

  function setVolume(percentage) {
    const n = Number.parseInt(percentage, 10);
    if (Number.isNaN(n))
      return "Invalid percentage";
    if (!root.sink?.audio)
      return "No audio sink available";

    const clamped = Math.max(0, Math.min(root.maxVolumePercent, n));
    setVolumeReal(clamped / 100);
    return `Volume set to ${clamped}%`;
  }

  function setVolumeReal(newVolume) {
    if (!root.sink?.audio)
      return;
    const clamped = clampVolume(newVolume);
    root.sink.audio.muted = false;
    root.sink.audio.volume = clamped;
  }

  function toggleMicMute() {
    if (!source?.audio)
      return "No audio source available";
    source.audio.muted = !source.audio.muted;
    micMuteChanged();
    return source.audio.muted ? "Microphone muted" : "Microphone unmuted";
  }

  function toggleMute() {
    if (!root.sink?.audio)
      return "No audio sink available";
    const next = !root.sink.audio.muted;
    setMuted(next);
    return next ? "Audio muted" : "Audio unmuted";
  }

  Component.onCompleted: {
    Logger.log("AudioService", `ready | sink: ${displayName(root.sink)} | volume: ${Math.round(root.volume * 100)}% | muted: ${root.muted} | source: ${displayName(root.source)}`);
  }
  onSinkChanged: {
    if (!root.sink?.audio) {
      Logger.log("AudioService", `sink changed: ${displayName(root.sink)} (no audio)`);
      return;
    }
    const vol = clampVolume(root.sink.audio.volume ?? 0);
    if (vol > root.maxVolume) {
      root.sink.audio.volume = root.maxVolume;
    }
    const deviceName = displayName(root.sink);
    const icon = deviceIconFor(root.sink);
    Logger.log("AudioService", `sink changed: ${deviceName}`);
    root.sinkDeviceChanged(deviceName, icon);
  }
  onSourceChanged: {
    Logger.log("AudioService", `source changed: ${displayName(root.source)}`);
    root.micMuteChanged();
  }

  PwObjectTracker {
    objects: root.sinks.concat(root.sources)
  }

  Connections {
    function onVolumeChanged() {
      if (!root.sink?.audio)
        return;
      const vol = root.clampVolume(root.sink.audio.volume ?? 0);
      if (vol > root.maxVolume) {
        root.sink.audio.volume = root.maxVolume;
      }
    }

    target: root.sink?.audio ?? null
  }

  Connections {
    function onMutedChanged() {
      root.micMuteChanged();
    }

    target: root.source?.audio ?? null
  }
}
