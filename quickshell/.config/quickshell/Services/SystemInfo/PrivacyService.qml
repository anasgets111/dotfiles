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
  property bool _v4l2DevicesPresent: false
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
  // Device nodes are invisible to file models, so a shell glob probes them:
  // 1 s in-use polling while /dev/video* exists, slow existence checks otherwise.
  Timer {
    interval: root._v4l2DevicesPresent ? 1000 : 5000
    repeat: true
    running: true
    triggeredOnStart: true

    onTriggered: Command.run(["sh", "-c", `set -- /dev/video*; [ -e "$1" ] && { echo present; fuser -s "$@" && echo active; }`], result => {
      const output = result.stdout ?? "";
      root._v4l2DevicesPresent = output.includes("present");
      root._v4l2Active = output.includes("active");
    }, "privacy.v4l2")
  }
}
