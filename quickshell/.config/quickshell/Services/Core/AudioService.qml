pragma Singleton

import QtQuick
import QtMultimedia
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
  readonly property bool micMuted: source?.audio?.muted ?? false
  readonly property real micVolume: Math.max(0, source?.audio?.volume ?? 0)
  readonly property bool muted: sink?.audio?.muted ?? false
  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property string sinkIcon: deviceIconFor(sink)
  readonly property list<PwNode> sinks: Pipewire.nodes.values.filter(n => !n.isStream && n.isSink)
  readonly property PwNode source: Pipewire.defaultAudioSource
  readonly property list<PwNode> sources: Pipewire.nodes.values.filter(n => !n.isStream && !n.isSink && n.audio)
  readonly property real stepVolume: 0.05
  readonly property list<PwNode> streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio)
  readonly property real volume: Math.max(0, sink?.audio?.volume ?? 0)

  signal sinkDeviceChanged(string deviceName, string icon)

  function clamp(volume) {
    return Math.max(0, Math.min(maxVolume, volume));
  }

  function decreaseVolume() {
    setVolume(root.volume - root.stepVolume);
  }

  function deviceIconFor(node) {
    if (!node)
      return "";
    const icon = deviceIconMap[node.properties?.["device.icon-name"]];
    if (icon)
      return icon;
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

    const name = node.name ?? "";
    const desc = node.description ?? "";
    if (desc && desc !== name)
      return desc;
    if (node.nickname && node.nickname !== name)
      return node.nickname;

    return name;
  }

  function increaseVolume() {
    setVolume(root.volume + root.stepVolume);
  }

  function playCriticalNotificationSound() {
    criticalNotificationSound.stop();
    criticalNotificationSound.play();
  }

  function playNormalNotificationSound() {
    normalNotificationSound.stop();
    normalNotificationSound.play();
  }

  function parsePercentage(valueString) {
    const n = parseInt(valueString, 10);
    return isNaN(n) ? null : n / 100;
  }

  function setAudioSink(newSink) {
    Pipewire.preferredDefaultAudioSink = newSink;
  }

  function setAudioSource(newSource) {
    Pipewire.preferredDefaultAudioSource = newSource;
  }

  function setInputVolume(newVolume) {
    if (!root.source?.audio)
      return;
    root.source.audio.muted = false;
    root.source.audio.volume = Math.max(0, Math.min(1.0, newVolume));
  }

  function setMicVolume(percentage) {
    const v = parsePercentage(percentage);
    if (v === null)
      return "Invalid percentage";
    if (!source?.audio)
      return "No audio source available";
    setInputVolume(v);
    return `Microphone volume set to ${Math.round(source.audio.volume * 100)}%`;
  }

  function setMuted(muted) {
    if (root.sink?.audio)
      root.sink.audio.muted = !!muted;
  }

  function setVolume(newVolume) {
    if (!root.sink?.audio)
      return;
    root.sink.audio.muted = false;
    root.sink.audio.volume = clamp(newVolume);
  }

  // IPC enty point (accepts percentage string)
  function setVolumePercent(percentage) {
    const v = parsePercentage(percentage);
    if (v === null)
      return "Invalid percentage";
    if (!root.sink?.audio)
      return "No audio sink available";
    setVolume(v);
    return `Volume set to ${Math.round(root.volume * 100)}%`;
  }

  function toggleMicMute() {
    if (!source?.audio)
      return "No audio source available";
    source.audio.muted = !source.audio.muted;
    return source.audio.muted ? "Microphone muted" : "Microphone unmuted";
  }

  function toggleMute() {
    if (!root.sink?.audio)
      return "No audio sink available";
    root.sink.audio.muted = !root.sink.audio.muted;
    return root.muted ? "Audio muted" : "Audio unmuted";
  }

  Component.onCompleted: {
    Logger.log("AudioService", `ready | sink: ${displayName(root.sink)} | volume: ${Math.round(root.volume * 100)}% | muted: ${root.muted} | source: ${displayName(root.source)}`);
  }
  onSinkChanged: {
    const name = displayName(root.sink);
    if (!root.sink?.audio) {
      Logger.log("AudioService", `sink changed: ${name} (no audio)`);
      return;
    }
    if (root.sink.audio.volume > root.maxVolume)
      root.sink.audio.volume = root.maxVolume;
    Logger.log("AudioService", `sink changed: ${name}`);
    root.sinkDeviceChanged(name, deviceIconFor(root.sink));
  }
  onSourceChanged: Logger.log("AudioService", `source changed: ${displayName(root.source)}`)

  MediaDevices {
    id: mediaDevices

    onDefaultAudioOutputChanged: Logger.log("AudioService", `default audio output changed to: ${defaultAudioOutput ? defaultAudioOutput.description : "None"}`)
  }

  AudioOutput {
    id: notificationOutput

    device: mediaDevices.defaultAudioOutput
    volume: 1.0
  }

  MediaPlayer {
    id: normalNotificationSound

    audioOutput: notificationOutput
    source: "file:///usr/share/sounds/freedesktop/stereo/message.oga"
  }

  MediaPlayer {
    id: criticalNotificationSound

    audioOutput: notificationOutput
    source: "file:///usr/share/sounds/freedesktop/stereo/bell.oga"
  }

  PwObjectTracker {
    objects: root.sinks.concat(root.sources).concat(root.streams)
  }

  Connections {
    function onVolumeChanged() {
      if (root.sink?.audio && root.sink.audio.volume > root.maxVolume)
        root.sink.audio.volume = root.maxVolume;
    }

    target: root.sink?.audio ?? null
  }
}
