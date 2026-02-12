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
  readonly property var _pipewireNodes: Pipewire.nodes?.values ?? []
  readonly property bool micMuted: source?.audio?.muted ?? false
  readonly property real micVolume: Math.max(0, source?.audio?.volume ?? 0)
  readonly property bool muted: sink?.audio?.muted ?? false
  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property string sinkIcon: deviceIconFor(sink)
  readonly property list<PwNode> sinks: _pipewireNodes.filter(node => !node.isStream && node.isSink)
  readonly property PwNode source: Pipewire.defaultAudioSource
  readonly property list<PwNode> sources: _pipewireNodes.filter(node => !node.isStream && !node.isSink && node.audio)
  readonly property real stepVolume: 0.05
  readonly property list<PwNode> streams: _pipewireNodes.filter(node => node.isStream && node.audio)
  readonly property real volume: Math.max(0, sink?.audio?.volume ?? 0)

  signal sinkDeviceChanged(string deviceName, string icon)

  function clamp(volume: real): real {
    return Math.max(0, Math.min(maxVolume, volume));
  }

  function decreaseVolume(): void {
    setVolume(root.volume - root.stepVolume);
  }

  function deviceIconFor(node: var): string {
    if (!node)
      return "";
    const mappedIcon = deviceIconMap[node.properties?.["device.icon-name"]];
    if (mappedIcon)
      return mappedIcon;
    const description = (node.description ?? "").toLowerCase();
    for (const key in deviceIconMap)
      if (description.includes(key))
        return deviceIconMap[key];
    return node.name?.startsWith("bluez_output") ? deviceIconMap["headphone"] : "";
  }

  function displayName(node: var): string {
    if (!node)
      return "";
    const properties = node.properties ?? {};
    if (properties["device.description"])
      return properties["device.description"];

    const name = node.name ?? "";
    const description = node.description ?? "";
    if (description && description !== name)
      return description;
    if (node.nickname && node.nickname !== name)
      return node.nickname;

    return name;
  }

  function increaseVolume(): void {
    setVolume(root.volume + root.stepVolume);
  }

  function playCriticalNotificationSound(): void {
    criticalNotificationSound.stop();
    criticalNotificationSound.play();
  }

  function playNormalNotificationSound(): void {
    normalNotificationSound.stop();
    normalNotificationSound.play();
  }

  function parsePercentage(rawPercentage: var): real {
    const percentageText = String(rawPercentage ?? "").trim();
    if (!/^-?\d+$/.test(percentageText))
      return Number.NaN;
    const percentageNumber = Number(percentageText);
    return Number.isSafeInteger(percentageNumber) ? percentageNumber / 100 : Number.NaN;
  }

  function setAudioSink(newSink: var): void {
    Pipewire.preferredDefaultAudioSink = newSink;
  }

  function setAudioSource(newSource: var): void {
    Pipewire.preferredDefaultAudioSource = newSource;
  }

  function setInputVolume(newVolume: real): void {
    if (!root.source?.audio)
      return;
    root.source.audio.muted = false;
    root.source.audio.volume = Math.max(0, Math.min(1.0, newVolume));
  }

  function setMicVolume(percentage: var): string {
    const parsedPercentage = parsePercentage(percentage);
    if (!Number.isFinite(parsedPercentage))
      return "Invalid percentage";
    if (!source?.audio)
      return "No audio source available";
    setInputVolume(parsedPercentage);
    return `Microphone volume set to ${Math.round(source.audio.volume * 100)}%`;
  }

  function setMuted(mutedState: bool): void {
    if (root.sink?.audio)
      root.sink.audio.muted = !!mutedState;
  }

  function setVolume(newVolume: real): void {
    if (!root.sink?.audio)
      return;
    root.sink.audio.muted = false;
    root.sink.audio.volume = clamp(newVolume);
  }

  // IPC entry point (accepts percentage string)
  function setVolumePercent(percentage: var): string {
    const parsedPercentage = parsePercentage(percentage);
    if (!Number.isFinite(parsedPercentage))
      return "Invalid percentage";
    if (!root.sink?.audio)
      return "No audio sink available";
    setVolume(parsedPercentage);
    return `Volume set to ${Math.round(root.volume * 100)}%`;
  }

  function capSinkVolume(): void {
    if (root.sink?.audio && root.sink.audio.volume > root.maxVolume)
      root.sink.audio.volume = root.maxVolume;
  }

  function toggleMicMute(): string {
    if (!source?.audio)
      return "No audio source available";
    source.audio.muted = !source.audio.muted;
    return source.audio.muted ? "Microphone muted" : "Microphone unmuted";
  }

  function toggleMute(): string {
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
    capSinkVolume();
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
      capSinkVolume();
    }

    target: root.sink?.audio ?? null
  }
}
