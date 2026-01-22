pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
  id: root

  readonly property bool cameraActive: {
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

  PwObjectTracker {
    objects: Pipewire.nodes?.values.filter(n => !n?.isStream) ?? []
  }
}
