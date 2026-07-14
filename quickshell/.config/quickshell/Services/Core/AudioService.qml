pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Services.Utils

Singleton {
  id: root

  readonly property var _audioNodes: (Pipewire.nodes?.values ?? []).filter(node => !!node?.ready && !!node.audio)
  readonly property var _deviceIconMap: ({
      "headphone": "󰋋",
      "hands-free": "󰋎",
      "headset": "󰋎",
      "phone": "󰏲",
      "portable": "󰏲"
    })
  property var _dndMutedStreamIds: []
  readonly property var _trackerObjects: (Pipewire.nodes?.values ?? []).concat(Pipewire.linkGroups?.values ?? [])
  property bool dndActive: false
  readonly property real maxVolume: 1.5
  readonly property bool micMuted: audioMuted(source)
  readonly property real micVolume: audioVolume(source)
  readonly property bool muted: audioMuted(sink)
  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property bool sinkControllable: hasControllableAudio(sink)
  readonly property string sinkIcon: deviceIconFor(sink)
  readonly property var sinkModels: buildAudioDevices(sinks, sink)
  readonly property string sinkName: displayName(sink)
  readonly property list<PwNode> sinks: _audioNodes.filter(node => !node.isStream && node.isSink)
  readonly property PwNode source: Pipewire.defaultAudioSource
  readonly property bool sourceControllable: hasControllableAudio(source)
  readonly property var sourceModels: buildAudioDevices(sources, source)
  readonly property string sourceName: displayName(source)
  readonly property list<PwNode> sources: _audioNodes.filter(node => !node.isStream && !node.isSink)
  readonly property var streamModels: root.streams.map(stream => {
    const rawName = stream.name || "";
    return {
      id: stream.id,
      name: Utils.lookupDesktopEntryName(rawName) || rawName || qsTr("Unknown"),
      iconSource: Utils.resolveIconSource(rawName, nodeProperties(stream)["application.icon-name"] ?? "", "󰝚")
    };
  })
  readonly property list<PwNode> streams: _audioNodes.filter(node => node.isStream)
  readonly property real volume: audioVolume(sink)

  function _muteDndStreams(): void {
    for (const stream of streams) {
      if (stream.audio.muted || _dndMutedStreamIds.includes(stream.id))
        continue;
      const props = nodeProperties(stream);
      if (props["media.role"] !== "Notification")
        continue;
      stream.audio.muted = true;
      _dndMutedStreamIds = [..._dndMutedStreamIds, stream.id];
    }
  }

  function _nodeById(nodes: var, id: int): var {
    return nodes.find(node => node.id === id) ?? null;
  }

  function _notificationHint(notification: var, key: string): var {
    const hints = notification?.hints ?? ({});
    const value = hints[key];
    return value?.value ?? value;
  }

  function _notificationSoundFile(pathOrUri: var): string {
    if (typeof pathOrUri !== "string" || pathOrUri.length === 0)
      return "";
    if (pathOrUri.startsWith("file://")) {
      const path = pathOrUri.substring("file://".length).replace(/^[^/]*/, "");
      try {
        return decodeURIComponent(path);
      } catch (e) {
        return path;
      }
    }
    return pathOrUri.startsWith("/") ? pathOrUri : "";
  }

  function _senderNotificationSoundActive(notification: var): bool {
    const senderPid = Number(_notificationHint(notification, "sender-pid"));
    if (!Number.isFinite(senderPid) || senderPid <= 0)
      return false;

    return (Pipewire.linkGroups?.values ?? []).some(link => {
      if (link?.state !== PwLinkState.Active)
        return false;
      const source = link.source;
      const props = nodeProperties(source);
      return Number(props["application.process.id"]) === senderPid && props["media.role"] === "Notification" && !audioMuted(source) && audioVolume(source) > 0;
    });
  }

  function _toggleError(node: var, unavailableMessage: string, notReadyMessage: string): string {
    if (!node)
      return unavailableMessage;
    if (!node.ready)
      return notReadyMessage;
    if (!node.audio)
      return unavailableMessage;
    return "";
  }

  function _unmuteDndStreams(): void {
    for (const stream of streams)
      if (_dndMutedStreamIds.includes(stream.id))
        stream.audio.muted = false;
    _dndMutedStreamIds = [];
  }

  function audioMuted(node: var): bool {
    return hasControllableAudio(node) ? !!node.audio.muted : false;
  }

  function audioVolume(node: var): real {
    if (!hasControllableAudio(node))
      return 0;
    const volume = node.audio.volume;
    return Number.isFinite(volume) ? Math.max(0, volume) : 0;
  }

  function buildAudioDevices(nodes: var, activeNode: var): var {
    return nodes.map(node => ({
          id: node.id,
          name: displayName(node),
          icon: deviceIconFor(node),
          active: node === activeNode
        }));
  }

  function capSinkVolume(): void {
    if (!root.sinkControllable)
      return;
    if (root.sink.audio.volume > root.maxVolume)
      setNodeVolume(root.sink, root.maxVolume, root.maxVolume, false);
  }

  function deviceIconFor(node: var): string {
    if (!node)
      return "";
    const properties = nodeProperties(node);
    const mappedIcon = _deviceIconMap[properties["device.icon-name"]];
    if (mappedIcon)
      return mappedIcon;
    const description = (node.description ?? "").toLowerCase();
    for (const key in _deviceIconMap)
      if (description.includes(key))
        return _deviceIconMap[key];
    const name = node.name ?? "";
    if (name.startsWith("bluez_output"))
      return _deviceIconMap["headphone"];
    if (name.startsWith("bluez_input"))
      return _deviceIconMap["headset"];
    return "";
  }

  function displayName(node: var): string {
    if (!node)
      return "";
    const properties = nodeProperties(node);
    if (properties["device.description"])
      return normalizeDeviceName(properties["device.description"]);

    const name = node.name ?? "";
    const description = node.description ?? "";
    if (description && description !== name)
      return normalizeDeviceName(description);
    if (node.nickname && node.nickname !== name)
      return normalizeDeviceName(node.nickname);

    return normalizeDeviceName(name);
  }

  function hasControllableAudio(node: var): bool {
    return !!node?.ready && !!node?.audio;
  }

  function nodeProperties(node: var): var {
    return !!node?.ready ? (node.properties ?? {}) : ({});
  }

  function normalizeDeviceName(raw: string): string {
    if (!raw)
      return raw;
    let cleaned = raw;
    cleaned = cleaned.replace(/\s*High Definition Audio Controller\b/i, "");
    cleaned = cleaned.replace(/\s*HD Audio Controller\b/i, "");
    cleaned = cleaned.replace(/\s*Audio Controller\b/i, "");
    cleaned = cleaned.replace(/\s*Digital Stereo\b/i, "");
    cleaned = cleaned.replace(/\s*Analog Stereo\b/i, "");
    cleaned = cleaned.replace(/\s*\(HDMI\)/i, " HDMI");
    cleaned = cleaned.replace(/\s*\(S\/PDIF\)/i, " S/PDIF");
    cleaned = cleaned.replace(/\s+/g, " ");
    return cleaned.trim() || raw;
  }

  function playNotificationSound(notification: var): void {
    const suppressSound = _notificationHint(notification, "suppress-sound");
    if (suppressSound === true || String(suppressSound).toLowerCase() === "true" || _senderNotificationSoundActive(notification))
      return;

    const soundDir = "/usr/share/sounds/freedesktop/stereo";
    const defaultSound = (notification?.urgency ?? 1) >= 2 ? `${soundDir}/bell.oga` : `${soundDir}/message.oga`;
    const soundPath = _notificationSoundFile(_notificationHint(notification, "sound-file")) || defaultSound;

    Command.detached(["pw-play", "--media-role", "Notification", "--volume", "0.8", soundPath]);
  }

  function setAudioSink(id: int): void {
    const node = _nodeById(root.sinks, id);
    if (node)
      Pipewire.preferredDefaultAudioSink = node;
  }

  function setAudioSource(id: int): void {
    const node = _nodeById(root.sources, id);
    if (node)
      Pipewire.preferredDefaultAudioSource = node;
  }

  function setInputVolume(newVolume: real): void {
    setNodeVolume(root.source, newVolume, 1.0, true);
  }

  function setNodeMuted(node: var, mutedState: bool): bool {
    if (!hasControllableAudio(node))
      return false;
    node.audio.muted = !!mutedState;
    return true;
  }

  function setNodeVolume(node: var, newVolume: real, maximum: real, unmute: bool): bool {
    if (!hasControllableAudio(node) || !Number.isFinite(newVolume))
      return false;
    if (unmute)
      node.audio.muted = false;
    node.audio.volume = Math.max(0, Math.min(maximum, newVolume));
    return true;
  }

  function setStreamVolume(id: int, newVolume: real): void {
    setNodeVolume(_nodeById(root.streams, id), newVolume, 1.0, true);
  }

  function setVolume(newVolume: real): void {
    setNodeVolume(root.sink, newVolume, root.maxVolume, true);
  }

  function streamReady(id: int): bool {
    return hasControllableAudio(_nodeById(root.streams, id));
  }

  function streamVolume(id: int): real {
    return audioVolume(_nodeById(root.streams, id));
  }

  function toggleMicMute(): string {
    const error = _toggleError(root.source, "No audio source available", "Audio source is not ready");
    if (error)
      return error;
    const nextMuted = !root.source.audio.muted;
    setNodeMuted(root.source, nextMuted);
    return nextMuted ? "Microphone muted" : "Microphone unmuted";
  }

  function toggleMute(): string {
    const error = _toggleError(root.sink, "No audio sink available", "Audio sink is not ready");
    if (error)
      return error;
    const nextMuted = !root.sink.audio.muted;
    setNodeMuted(root.sink, nextMuted);
    return nextMuted ? "Audio muted" : "Audio unmuted";
  }

  Component.onCompleted: {
    Logger.log("AudioService", `ready | sink: ${displayName(root.sink)} | volume: ${Math.round(root.volume * 100)}% | muted: ${root.muted} | source: ${displayName(root.source)}`);
  }
  onDndActiveChanged: dndActive ? _muteDndStreams() : _unmuteDndStreams()
  onSinkChanged: {
    const name = displayName(root.sink);
    if (!root.sink?.ready) {
      Logger.log("AudioService", `sink changed: ${name} (waiting for binding)`);
      return;
    }
    if (!root.sink.audio) {
      Logger.log("AudioService", `sink changed: ${name} (no audio)`);
      return;
    }
    root.capSinkVolume();
    Logger.log("AudioService", `sink changed: ${name}`);
  }
  onSourceChanged: Logger.log("AudioService", `source changed: ${displayName(root.source)}`)
  onStreamsChanged: {
    const liveIds = root.streams.map(stream => stream.id);
    root._dndMutedStreamIds = root._dndMutedStreamIds.filter(id => liveIds.includes(id));
    if (root.dndActive)
      root._muteDndStreams();
  }

  PwObjectTracker {
    objects: root._trackerObjects
  }

  Connections {
    function onReadyChanged() {
      if (root.sinkControllable)
        root.capSinkVolume();
    }

    target: root.sink ?? null
  }

  Connections {
    function onVolumeChanged() {
      root.capSinkVolume();
    }

    target: root.sinkControllable ? root.sink.audio : null
  }
}
