pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
  id: root

  readonly property var _patterns: ({
      camera: /camera|webcam|v4l2|uvc/i,
      screenshare: /xdg-desktop-portal|pipewire-screen-audio|obs|wf-recorder|gpu-screen-recorder|grim|slurp|wl-screenrec|screen.?share|desktop.?capture|display.?capture/i,
      virtual: /cava|monitor|system/i
    })
  readonly property var _status: {
    const state = {
      camera: false,
      microphone: false,
      screenshare: false
    };
    const links = Pipewire.linkGroups?.values;
    if (!links)
      return state;

    for (const {
      source,
      target
    } of links) {
      if (!source)
        continue;
      if (source.type === PwNodeType.VideoSource) {
        const info = _describe(source);
        if (!state.camera && _patterns.camera.test(info))
          state.camera = true;
        else if (!state.screenshare && _patterns.screenshare.test(info))
          state.screenshare = true;
      } else if (!state.microphone && source.type === PwNodeType.AudioSource && target?.type === PwNodeType.AudioInStream) {
        if (!target.audio?.muted && !_patterns.virtual.test(_describe(target))) {
          state.microphone = true;
        }
      }
      if (state.camera && state.microphone && state.screenshare)
        break;
    }
    return state;
  }
  readonly property bool cameraActive: _status.camera
  readonly property bool microphoneActive: _status.microphone
  readonly property bool microphoneMuted: Pipewire.defaultAudioSource?.audio?.muted ?? false
  readonly property bool screenshareActive: _status.screenshare

  function _describe(node: PwNode): string {
    if (!node)
      return "";
    const props = node.properties;
    return [node.name, props["media.name"], props["application.name"]].filter(Boolean).join(" ").toLowerCase();
  }
}
