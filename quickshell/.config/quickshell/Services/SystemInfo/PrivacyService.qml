pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
  id: root

  readonly property bool _pipewireCamera: {
    const links = Pipewire.linkGroups?.values;
    if (!links)
      return false;

    for (const {
      source
    } of links) {
      if (source?.type === PwNodeType.VideoSource && _looksLikeCamera(source)) {
        return true;
      }
    }
    return false;
  }
  readonly property bool _v4l2Camera: v4l2Process.running ? v4l2Collector.text.trim().length > 0 : false
  readonly property bool cameraActive: _pipewireCamera || _v4l2Camera
  readonly property bool microphoneActive: {
    const links = Pipewire.linkGroups?.values;
    if (!links)
      return false;

    for (const {
      source,
      target
    } of links) {
      if (source?.type === PwNodeType.AudioSource && target?.type === PwNodeType.AudioInStream && !target.audio?.muted && !_isVirtual(target)) {
        return true;
      }
    }
    return false;
  }
  readonly property bool microphoneMuted: Pipewire.defaultAudioSource?.audio?.muted ?? false
  readonly property bool screenshareActive: {
    if (!Pipewire.ready)
      return false;

    for (const node of Pipewire.nodes?.values ?? []) {
      if ((node?.type & PwNodeType.VideoSource) && /xdg-desktop-portal|screencast|obs/.test(_describe(node))) {
        return true;
      }
    }
    return false;
  }

  function _describe(node: PwNode): string {
    const p = node?.properties ?? {};
    return [node?.name, p["application.name"], p["media.name"]].filter(Boolean).join(" ").toLowerCase();
  }

  function _isVirtual(node: PwNode): bool {
    return /cava|monitor|system/.test(_describe(node));
  }

  function _looksLikeCamera(node: PwNode): bool {
    const desc = _describe(node);
    return /camera|webcam|video|v4l2/.test(desc) && !/screen|desktop|obs|xdg/.test(desc);
  }

  Process {
    id: v4l2Process

    command: ["sh", "-c", "fuser /dev/video* 2>/dev/null"]
    running: true

    stdout: SplitParser {
      id: v4l2Collector

      onRead: data => v4l2Timer.restart()
    }
  }

  Timer {
    id: v4l2Timer

    interval: 2000

    onTriggered: v4l2Process.running = false
  }

  Timer {
    interval: 1000
    repeat: true
    running: true

    onTriggered: {
      if (!v4l2Process.running) {
        v4l2Process.running = true;
      }
    }
  }

  PwObjectTracker {
    objects: Pipewire.nodes?.values.filter(n => !n?.isStream) ?? []
  }
}
