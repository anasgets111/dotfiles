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
  readonly property var _screencastPattern: /xdg-desktop-portal|xdpw|screencast|screen|niri|gnome shell|kwin|obs|wf-recorder|grim|slurp|screen.?share|display.?capture/
  property bool _v4l2Active: false
  readonly property bool audioCaptureActive: _activeLinks.some(link => root._isCapture(link))
  readonly property bool cameraActive: _v4l2Active
  readonly property bool microphoneActive: _activeLinks.some(link => root._isCapture(link) && link.target.ready && !!link.target.audio && !link.target.audio.muted)
  readonly property bool microphoneMuted: AudioService.micMuted
  readonly property bool screenshareActive: _activeLinks.some(link => root._isScreencast(link.source)) || (Pipewire.nodes?.values ?? []).some(node => /\bniri\b/.test(_describe(node)))

  function _describe(node: var): string {
    const properties = node?.ready ? (node.properties ?? {}) : {};
    return [node?.name, properties["media.name"], properties["application.name"]].filter(Boolean).join(" ").toLowerCase();
  }
  function _isCapture(link: var): bool {
    return link.source?.type === PwNodeType.AudioSource && link.target?.type === PwNodeType.AudioInStream && !/\bcava\b/.test(_describe(link.target));
  }
  function _isScreencast(source: var): bool {
    return (source?.type & PwNodeType.VideoSource) === PwNodeType.VideoSource && root._screencastPattern.test(_describe(source));
  }

  PwObjectTracker {
    objects: (Pipewire.nodes?.values ?? []).concat(Pipewire.linkGroups?.values ?? [])
  }
  // `exec` keeps the watcher to one process that dies with the stream; fuser
  // still has to confirm, because one close need not be the last one.
  CommandStream {
    active: true
    command: ["sh", "-c", "exec inotifywait -q -m -e open,close --format %e -- /dev/video*"]
    restartDelay: 5000

    onLineRead: v4l2Refresh.restart()
  }
  Timer {
    id: v4l2Refresh

    interval: 150
    running: true

    onTriggered: Command.run(["sh", "-c", "fuser -s /dev/video*"], result => root._v4l2Active = result.exitCode === 0, "privacy.v4l2")
  }
}
