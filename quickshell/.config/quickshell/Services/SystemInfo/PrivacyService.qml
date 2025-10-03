pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Services.Core

Singleton {
  id: root

  // Small helpers
  function lower(v) {
    return String(v || "").toLowerCase();
  }
  function truthy(v) {
    const s = lower(v);
    return s === "true" || s === "1";
  }
  function prop(node, key) {
    if (!node)
      return "<unset>";
    const p = node.properties || {};
    if (p[key] !== undefined && p[key] !== null && p[key] !== "")
      return p[key];
    const g = node.globalProperties || {};
    if (g[key] !== undefined && g[key] !== null && g[key] !== "")
      return g[key];
    const info = node.info && (node.info.properties || node.info.props || node.info.propertiesMap);
    if (info && info[key] !== undefined && info[key] !== null && info[key] !== "")
      return info[key];
    const meta = node.metadata || {};
    if (meta[key] !== undefined && meta[key] !== null && meta[key] !== "")
      return meta[key];
    return "<unset>";
  }

  // Core booleans
  readonly property bool microphoneActive: {
    const nodes = Pipewire.nodes?.values || [];
    return nodes.some(n => n && (n.type & PwNodeType.AudioInStream) === PwNodeType.AudioInStream && !isSystemVirtualMic(n) && !(n.audio && n.audio.muted));
  }

  // New: show if any real mic stream is muted
  readonly property bool microphoneMuted: {
    const sourceAudio = AudioService && AudioService.source && AudioService.source.audio ? AudioService.source.audio : null;
    if (sourceAudio)
      return !!sourceAudio.muted;

    const nodes = Pipewire.nodes?.values || [];
    return nodes.some(n => n && (n.type & PwNodeType.AudioInStream) === PwNodeType.AudioInStream && !isSystemVirtualMic(n) && !!(n.audio && n.audio.muted));
  }

  readonly property bool cameraActive: {
    const nodes = Pipewire.nodes?.values || [];
    const links = Pipewire.links?.values || [];

    const isActiveLink = l => l?.active === true || /active|running|connected|streaming|live|started/.test(lower(l?.state || l?.info?.state));

    const hasActiveVideoLink = n => links.some(l => (l?.outputNodeId === n?.id || l?.inputNodeId === n?.id) && isActiveLink(l));

    const activeState = n => {
      const live = lower(prop(n, "stream.is-live") || prop(n, "stream.active") || prop(n, "device.active"));
      const state = lower(n?.state || prop(n, "node.state"));
      const session = lower(prop(n, "session.active") || prop(n, "session.is-active"));
      const started = lower(prop(n, "node.started"));
      return truthy(live) || /running|active|playing|streaming|recording|started/.test(state) || truthy(session) || truthy(started) || hasActiveVideoLink(n);
    };

    return nodes.some(n => isVideoNode(n) && !isScreencast(n) && activeState(n) && isCameraNode(n));
  }

  readonly property bool screensharingActive: {
    const nodes = Pipewire.nodes?.values || [];
    if (nodes.some(n => isVideoNode(n) && isScreencast(n)))
      return true;

    // Some portals/apps expose an audio input stream alongside desktop capture
    return nodes.some(n => {
      if (!n)
        return false;
      if ((n.properties || {})["media.class"] !== "Stream/Input/Audio")
        return false;

      const mediaName = lower(prop(n, "media.name"));
      const appName = lower(prop(n, "application.name"));
      const live = truthy(prop(n, "stream.is-live"));
      const muted = !!(n.audio && n.audio.muted);
      const role = mediaRole(n);

      const looksLikeDesktop = mediaName.includes("desktop") || appName.includes("screen") || appName === "obs" || role.includes("screen") || role.includes("desktop") || role.includes("share");
      return live && looksLikeDesktop && !muted;
    });
  }

  readonly property bool anyPrivacyActive: microphoneActive || cameraActive || screensharingActive

  // PipeWire binding to expose full properties (e.g., audio.muted)
  PwObjectTracker {
    id: nodeTracker
    objects: Pipewire.nodes?.values || []
  }
  PwObjectTracker {
    id: linkTracker
    objects: Pipewire.links?.values || []
  }

  Component.onDestruction: {
    nodeTracker.objects = [];
    linkTracker.objects = [];
  }

  // Helpers
  function nodeDescription(node) {
    return lower(prop(node, "node.description") || node?.description);
  }
  function mediaRole(node) {
    return lower(prop(node, "media.role") || prop(node, "stream.capture.category") || prop(node, "capture.category"));
  }
  function mediaClass(node) {
    return lower(prop(node, "media.class") || prop(node, "node.media.class"));
  }

  function isSystemVirtualMic(node) {
    if (!node)
      return false;
    const text = [lower(node.name), lower(prop(node, "media.name")), lower(prop(node, "application.name"))].join(" ");
    return text.search(/cava|monitor|system/) !== -1;
  }

  function isVideoNode(node) {
    if (!node)
      return false;
    if ((node.type & PwNodeType.VideoSource) === PwNodeType.VideoSource)
      return true;
    const klass = mediaClass(node);
    const role = mediaRole(node);
    return klass.includes("video") || klass.includes("camera") || role.includes("camera") || role.includes("video");
  }

  function isCameraNode(node) {
    if (!node)
      return false;
    const role = mediaRole(node);
    if (role.includes("camera") || role.includes("webcam"))
      return true;

    const combined = lower([node?.name || "", prop(node, "media.name") || "", nodeDescription(node) || ""].join(" "));
    if (combined.search(/\bcamera\b|\bwebcam\b|\bv4l2\b|\buvc\b/) !== -1)
      return true;
    if (combined.search(/webrtc-consume-stream|\bconsume-stream\b/) !== -1)
      return false;

    return false;
  }

  function isScreencast(node) {
    if (!node)
      return false;
    const role = mediaRole(node);
    if (role.includes("camera") || role.includes("webcam"))
      return false;

    const camText = lower([prop(node, "application.name"), node?.name, nodeDescription(node), prop(node, "media.name")].join(" "));
    if (camText.search(/\bcamera\b|\bwebcam\b|v4l2|uvc/) !== -1)
      return false;
    if (role.includes("screen") || role.includes("desktop") || role.includes("share"))
      return true;

    const klass = mediaClass(node);
    if (klass.includes("stream/output/video"))
      return true;

    return camText.search(/xdg-desktop-portal|xdpw|screencast|screen-record|screen cast|gnome shell|kwin|obs|niri-screen-cast/) !== -1;
  }
}
