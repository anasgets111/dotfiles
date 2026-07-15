pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Services.Core
import qs.Services.Utils

Singleton {
  id: root

  readonly property var _activeLinks: (Pipewire.linkGroups?.values ?? []).filter(link => link.state === PwLinkState.Active)
  readonly property var _trackerObjects: (Pipewire.nodes?.values ?? []).concat(Pipewire.linkGroups?.values ?? [])
  property bool _v4l2Active: false
  readonly property bool audioCaptureActive: _activeLinks.some(link => link.source?.type === PwNodeType.AudioSource && link.target?.type === PwNodeType.AudioInStream && !/\bcava\b/.test(_describe(link.target)))
  readonly property bool cameraActive: _v4l2Active
  readonly property bool microphoneActive: _activeLinks.some(link => {
    const source = link.source;
    const target = link.target;
    const targetAudio = target?.ready ? target.audio : null;
    return source?.type === PwNodeType.AudioSource && target?.type === PwNodeType.AudioInStream && targetAudio && !targetAudio.muted && !/\bcava\b/.test(_describe(target));
  })
  readonly property bool microphoneMuted: AudioService.micMuted
  readonly property bool screenshareActive: _activeLinks.some(link => {
    const source = link.source;
    return (source?.type & PwNodeType.VideoSource) === PwNodeType.VideoSource && /xdg-desktop-portal|xdpw|screencast|screen|gnome shell|kwin|obs|wf-recorder|grim|slurp|screen.?share|display.?capture/.test(_describe(source));
  })

  function _describe(node: var): string {
    if (!node)
      return "";
    const properties = node.ready ? (node.properties ?? {}) : {};
    return [node.name, properties?.["media.name"], properties?.["application.name"]].filter(Boolean).join(" ").toLowerCase();
  }

  PwObjectTracker {
    objects: root._trackerObjects
  }
  Timer {
    interval: 1000
    repeat: true
    running: true

    onTriggered: Command.run(["sh", "-c", "fuser -s /dev/video* 2>/dev/null"], result => root._v4l2Active = (result.exitCode === 0), "privacy.v4l2")
  }
}
