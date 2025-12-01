pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Services.Core

Singleton {
  id: root

  readonly property var _cameraPattern: /camera|webcam|v4l2|uvc/
  readonly property var _privacyState: {
    const result = {
      camera: false,
      mic: false,
      screenshare: false
    };
    const groups = Pipewire.linkGroups?.values;
    if (!groups)
      return result;

    for (const lg of groups) {
      if (lg.source?.type === PwNodeType.VideoSource) {
        const info = _getNodeInfo(lg.source);
        if (_cameraPattern.test(info))
          result.camera = true;
        else if (_screensharePattern.test(info))
          result.screenshare = true;
      }
      if (lg.source?.type === PwNodeType.AudioSource && lg.target?.type === PwNodeType.AudioInStream) {
        const info = _getNodeInfo(lg.target);
        if (!_virtualMicPattern.test(info) && !lg.target.audio?.muted)
          result.mic = true;
      }
    }
    return result;
  }
  readonly property var _screensharePattern: /xdg-desktop-portal|pipewire-screen-audio|obs|wf-recorder|gpu-screen-recorder|grim|slurp|wl-screenrec|screen.?share|desktop.?capture|display.?capture/
  readonly property var _virtualMicPattern: /cava|monitor|system/
  readonly property bool cameraActive: _privacyState.camera
  readonly property bool microphoneActive: _privacyState.mic
  readonly property bool microphoneMuted: AudioService?.source?.audio?.muted ?? false
  readonly property bool screensharingActive: _privacyState.screenshare

  function _getNodeInfo(node) {
    if (!node)
      return "";
    const props = node.properties;
    return [node.name, props?.["media.name"], props?.["application.name"]].filter(Boolean).join(" ").toLowerCase();
  }
}
