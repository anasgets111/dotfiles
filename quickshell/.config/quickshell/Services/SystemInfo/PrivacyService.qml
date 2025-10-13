pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Services.Core

Singleton {
  id: root

  readonly property var audioInStreams: Pipewire.linkGroups?.values.filter(lg => lg.source.type === PwNodeType.AudioSource && lg.target.type === PwNodeType.AudioInStream).map(lg => lg.target) || []

  // Privacy states
  readonly property bool cameraActive: videoSources.some(n => isCameraNode(n))
  readonly property bool microphoneActive: audioInStreams.some(n => !isSystemVirtualMic(n) && !(n.audio?.muted))
  readonly property bool microphoneMuted: AudioService?.source?.audio?.muted ?? false
  readonly property bool screensharingActive: videoSources.some(n => !isCameraNode(n))

  // Cached lists to avoid redundant calculations
  readonly property var videoSources: Pipewire.linkGroups?.values.filter(lg => lg.source.type === PwNodeType.VideoSource).map(lg => lg.source) || []

  function isCameraNode(node) {
    if (!node)
      return false;

    const name = String(node.name || "").toLowerCase();
    const mediaName = String(node.properties?.["media.name"] || "").toLowerCase();
    const appName = String(node.properties?.["application.name"] || "").toLowerCase();
    const combined = name + " " + mediaName + " " + appName;

    if (/camera|webcam|v4l2|uvc/.test(combined))
      return true;

    if (/webrtc-consume-stream|consume-stream/.test(combined))
      return false;

    return false;
  }

  function isSystemVirtualMic(node) {
    if (!node)
      return false;

    const name = String(node.name || "").toLowerCase();
    const mediaName = String(node.properties?.["media.name"] || "").toLowerCase();
    const appName = String(node.properties?.["application.name"] || "").toLowerCase();

    return /cava|monitor|system/.test(name + " " + mediaName + " " + appName);
  }
}
