pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io

Singleton {
  id: root

  readonly property var _activeLinks: (Pipewire.linkGroups?.values ?? []).filter(link => link.state === PwLinkState.Active)
  property bool _v4l2Active: false
  readonly property bool cameraActive: _v4l2Active
  readonly property bool microphoneActive: _activeLinks.some(link => {
      const source = link.source;
      const target = link.target;
      const targetAudio = target?.audio;
      return source?.type === PwNodeType.AudioSource && target?.type === PwNodeType.AudioInStream && targetAudio && !targetAudio.muted && !/\bcava\b/.test(_describe(target));
    })
  readonly property bool microphoneMuted: Pipewire.defaultAudioSource?.audio?.muted ?? false
  readonly property bool screenshareActive: _activeLinks.some(link => {
      const source = link.source;
      return (source?.type & PwNodeType.VideoSource) === PwNodeType.VideoSource && /xdg-desktop-portal|xdpw|screencast|screen|gnome shell|kwin|obs|wf-recorder|grim|slurp|screen.?share|display.?capture/.test(_describe(source));
    })

  function _describe(node: var): string {
    if (!node)
      return "";
    const properties = node.properties;
    return [node.name, properties?.["media.name"], properties?.["application.name"]].filter(Boolean).join(" ").toLowerCase();
  }

  PwObjectTracker {
    objects: (Pipewire.nodes?.values ?? []).concat(Pipewire.linkGroups?.values ?? [])
  }

  Process {
    id: v4l2Process

    command: ["fuser", "-s", "/dev/video0", "/dev/video1", "/dev/video2"]

    onExited: code => root._v4l2Active = (code === 0)
  }

  Timer {
    interval: 250
    repeat: true
    running: true

    onTriggered: if (!v4l2Process.running)
      v4l2Process.running = true
  }
}
