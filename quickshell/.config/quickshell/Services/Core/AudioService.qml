pragma Singleton

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Services.Pipewire
import qs.Services.Utils

Singleton {
  id: root

  readonly property var _pipewireNodes: Pipewire.nodes?.values ?? []
  readonly property var deviceIconMap: ({
      "headphone": "󰋋",
      "hands-free": "󰋎",
      "headset": "󰋎",
      "phone": "󰏲",
      "portable": "󰏲"
    })
  readonly property real maxVolume: 1.5
  readonly property bool micMuted: audioMuted(source)
  readonly property real micVolume: audioVolume(source)
  readonly property bool muted: audioMuted(sink)
  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property bool sinkControllable: hasControllableAudio(sink)
  readonly property string sinkIcon: deviceIconFor(sink)
  readonly property list<PwNode> sinks: _pipewireNodes.filter(node => !node.isStream && node.isSink)
  readonly property PwNode source: Pipewire.defaultAudioSource
  readonly property bool sourceControllable: hasControllableAudio(source)
  readonly property list<PwNode> sources: _pipewireNodes.filter(node => !node.isStream && !node.isSink && node.audio)
  readonly property real stepVolume: 0.05
  readonly property list<PwNode> streams: _pipewireNodes.filter(node => node.isStream && node.audio)
  readonly property real volume: audioVolume(sink)

  signal sinkDeviceChanged(string deviceName, string icon)

  function audioMuted(node: var): bool {
    return hasControllableAudio(node) ? !!node.audio.muted : false;
  }

  function audioVolume(node: var): real {
    if (!hasControllableAudio(node))
      return 0;
    const volume = node.audio.volume;
    return Number.isFinite(volume) ? Math.max(0, volume) : 0;
  }

  function capSinkVolume(): void {
    if (!root.sinkControllable)
      return;
    if (root.sink.audio.volume > root.maxVolume)
      setNodeVolume(root.sink, root.maxVolume, root.maxVolume);
  }

  function clampVolume(volume: real, maximum: real): real {
    return Math.max(0, Math.min(maximum, volume));
  }

  function decreaseVolume(): void {
    setVolume(root.volume - root.stepVolume);
  }

  function deviceIconFor(node: var): string {
    if (!node)
      return "";
    const properties = nodeProperties(node);
    const mappedIcon = deviceIconMap[properties["device.icon-name"]];
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
    const properties = nodeProperties(node);
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

  function hasControllableAudio(node: var): bool {
    return isNodeReady(node) && !!node?.audio;
  }

  function increaseVolume(): void {
    setVolume(root.volume + root.stepVolume);
  }

  function isNodeReady(node: var): bool {
    return !!node?.ready;
  }

  function nodeApplicationIconName(node: var): string {
    return nodeProperties(node)["application.icon-name"] ?? "";
  }

  function nodeProperties(node: var): var {
    return isNodeReady(node) ? (node.properties ?? {}) : ({});
  }

  function parsePercentage(rawPercentage: var): real {
    const percentageText = String(rawPercentage ?? "").trim();
    if (!/^-?\d+$/.test(percentageText))
      return Number.NaN;
    const percentageNumber = Number(percentageText);
    return Number.isSafeInteger(percentageNumber) ? percentageNumber / 100 : Number.NaN;
  }

  function playCriticalNotificationSound(): void {
    criticalNotificationSound.stop();
    criticalNotificationSound.play();
  }

  function playNormalNotificationSound(): void {
    normalNotificationSound.stop();
    normalNotificationSound.play();
  }

  function setAudioSink(newSink: var): void {
    Pipewire.preferredDefaultAudioSink = newSink;
  }

  function setAudioSource(newSource: var): void {
    Pipewire.preferredDefaultAudioSource = newSource;
  }

  function setInputVolume(newVolume: real): void {
    if (!root.sourceControllable)
      return;
    setNodeVolume(root.source, newVolume, 1.0);
  }

  function setMicVolume(percentage: var): string {
    const parsedPercentage = parsePercentage(percentage);
    if (!Number.isFinite(parsedPercentage))
      return "Invalid percentage";
    if (!source?.audio)
      return "No audio source available";
    if (!root.sourceControllable)
      return "Audio source is not ready";
    setInputVolume(parsedPercentage);
    return `Microphone volume set to ${Math.round(audioVolume(root.source) * 100)}%`;
  }

  function setNodeMuted(node: var, mutedState: bool): bool {
    if (!hasControllableAudio(node))
      return false;
    node.audio.muted = !!mutedState;
    return true;
  }

  function setNodeVolume(node: var, newVolume: real, maximum: real): bool {
    if (!hasControllableAudio(node))
      return false;
    node.audio.muted = false;
    node.audio.volume = clampVolume(newVolume, maximum);
    return true;
  }

  function setStreamVolume(stream: var, newVolume: real): void {
    setNodeVolume(stream, newVolume, 1.0);
  }

  function setVolume(newVolume: real): void {
    if (!root.sinkControllable)
      return;
    setNodeVolume(root.sink, newVolume, root.maxVolume);
  }

  // IPC entry point (accepts percentage string)
  function setVolumePercent(percentage: var): string {
    const parsedPercentage = parsePercentage(percentage);
    if (!Number.isFinite(parsedPercentage))
      return "Invalid percentage";
    if (!root.sink?.audio)
      return "No audio sink available";
    if (!root.sinkControllable)
      return "Audio sink is not ready";
    setVolume(parsedPercentage);
    return `Volume set to ${Math.round(root.volume * 100)}%`;
  }

  function toggleMicMute(): string {
    if (!source?.audio)
      return "No audio source available";
    if (!root.sourceControllable)
      return "Audio source is not ready";
    const nextMuted = !root.source.audio.muted;
    setNodeMuted(root.source, nextMuted);
    return nextMuted ? "Microphone muted" : "Microphone unmuted";
  }

  function toggleMute(): string {
    if (!root.sink?.audio)
      return "No audio sink available";
    if (!root.sinkControllable)
      return "Audio sink is not ready";
    const nextMuted = !root.sink.audio.muted;
    setNodeMuted(root.sink, nextMuted);
    return nextMuted ? "Audio muted" : "Audio unmuted";
  }

  Component.onCompleted: {
    Logger.log("AudioService", `ready | sink: ${displayName(root.sink)} | volume: ${Math.round(root.volume * 100)}% | muted: ${root.muted} | source: ${displayName(root.source)}`);
  }
  onSinkChanged: {
    const name = displayName(root.sink);
    root.sinkDeviceChanged(name, deviceIconFor(root.sink));
    if (!root.sink?.audio) {
      Logger.log("AudioService", `sink changed: ${name} (no audio)`);
      return;
    }
    if (!root.sink.ready) {
      Logger.log("AudioService", `sink changed: ${name} (waiting for binding)`);
      return;
    }
    capSinkVolume();
    Logger.log("AudioService", `sink changed: ${name}`);
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

    target: root.sinkControllable ? root.sink.audio : null
  }
}
