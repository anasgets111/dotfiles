pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io

Singleton {
  id: root

  readonly property var _privacyState: {
    const result = {
      mic: false,
      screenshare: false
    };
    const nodes = Pipewire.nodes?.values;

    if (!nodes)
      return result;

    for (const node of nodes) {
      if ((node.type & PwNodeType.VideoSource) === PwNodeType.VideoSource) {
        if (/xdg-desktop-portal|xdpw|screencast|screen|gnome shell|kwin|obs|wf-recorder|grim|slurp|screen.?share|display.?capture/.test(_describe(node))) {
          result.screenshare = true;
        }
      } else if ((node.type & PwNodeType.AudioSource) === PwNodeType.AudioSource) {
        if (!/cava|monitor|system/.test(_describe(node)) && !node.audio?.muted) {
          result.mic = true;
        }
      }
    }
    return result;
  }
  property bool _v4l2Active: false
  readonly property bool cameraActive: _v4l2Active
  readonly property bool microphoneActive: _privacyState.mic
  readonly property bool microphoneMuted: Pipewire.defaultAudioSource?.audio?.muted ?? false
  readonly property bool screenshareActive: _privacyState.screenshare

  function _describe(node) {
    if (!node)
      return "";
    const p = node.properties;
    return [node.name, p?.["media.name"], p?.["application.name"]].filter(Boolean).join(" ").toLowerCase();
  }

  Process {
    id: v4l2Process

    command: ["fuser", "-s", "/dev/video0", "/dev/video1", "/dev/video2", "/dev/video3"]

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
