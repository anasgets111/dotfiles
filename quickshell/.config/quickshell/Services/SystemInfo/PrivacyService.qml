pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
  id: root

  readonly property bool microphoneActive: {
    const nodes = Pipewire.ready ? (Pipewire.nodes?.values || []) : [];
    return nodes.some(n => n && (n.type & PwNodeType.AudioInStream) === PwNodeType.AudioInStream && !isSystemVirtualMic(n) && !(n.audio && n.audio.muted));
  }

  readonly property bool cameraActive: {
    const nodes = Pipewire.ready ? (Pipewire.nodes?.values || []) : [];
    if (nodes.length === 0)
      return false;

    const links = Pipewire.links?.values || [];
    const isActiveLink = l => {
      const s = String(l?.state || l?.info?.state || "").toLowerCase();
      return l?.active === true || /active|running|connected|streaming|live|started/.test(s);
    };

    const hasVideoPort = n => {
      const ports = n?.ports ? (n.ports.values || []) : [];
      return ports.some(p => {
        const props = p?.properties || {};
        const media = String(props["media.class"] || props["port.media.class"] || "").toLowerCase();
        const dsp = String(props["format.dsp.media-type"] || props["format.media-type"] || "").toLowerCase();
        const cat = String(props["port.category"] || "").toLowerCase();
        return media.includes("video") || dsp.includes("video") || cat.includes("capture");
      });
    };

    const hasActiveVideoLink = n => links.some(l => (l?.outputNodeId === n?.id || l?.inputNodeId === n?.id) && isActiveLink(l));

    const activeState = n => {
      const live = String(prop(n, "stream.is-live") || prop(n, "stream.active") || prop(n, "device.active")).toLowerCase();
      const state = String(n?.state || prop(n, "node.state") || "").toLowerCase();
      return live === "true" || live === "1" || state === "running" || n?.ready === true || hasVideoPort(n) || hasActiveVideoLink(n);
    };

    return nodes.some(n => n && (n.type & PwNodeType.VideoSource) === PwNodeType.VideoSource && !isScreencast(n) && activeState(n));
  }

  readonly property bool screensharingActive: {
    const nodes = Pipewire.ready ? (Pipewire.nodes?.values || []) : [];
    if (nodes.length === 0)
      return false;

    const videoScreencast = nodes.some(n => n && (n.type & PwNodeType.VideoSource) === PwNodeType.VideoSource && isScreencast(n));

    if (videoScreencast)
      return true;

    // Some portals/apps expose an audio input stream alongside desktop capture
    return nodes.some(n => {
      if (!n)
        return false;
      if ((n.properties || {})["media.class"] !== "Stream/Input/Audio")
        return false;

      const mediaName = String(prop(n, "media.name")).toLowerCase();
      const appName = String(prop(n, "application.name")).toLowerCase();
      const live = String(prop(n, "stream.is-live")).toLowerCase() === "true";
      const muted = !!(n.audio && n.audio.muted);

      const looksLikeDesktop = mediaName.includes("desktop") || appName.includes("screen") || appName === "obs";
      return live && looksLikeDesktop && !muted;
    });
  }

  readonly property bool anyPrivacyActive: microphoneActive || cameraActive || screensharingActive

  // Helpers
  function isSystemVirtualMic(node) {
    if (!node)
      return false;
    const name = String(node.name || "").toLowerCase();
    const mediaName = String(prop(node, "media.name")).toLowerCase();
    const appName = String(prop(node, "application.name")).toLowerCase();
    const text = name + " " + mediaName + " " + appName;
    return /cava|monitor|system/.test(text);
  }

  function isScreencast(node) {
    if (!node)
      return false;
    const appName = String(prop(node, "application.name")).toLowerCase();
    const nodeName = String(node.name || "").toLowerCase();
    const text = appName + " " + nodeName;
    return /xdg-desktop-portal|xdpw|screencast|screen|gnome shell|kwin|obs/.test(text);
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

  // Status helpers
  function getMicrophoneStatus() {
    return microphoneActive ? "active" : "inactive";
  }
  function getCameraStatus() {
    return cameraActive ? "active" : "inactive";
  }
  function getScreensharingStatus() {
    return screensharingActive ? "active" : "inactive";
  }
  function getPrivacySummary() {
    const active = [];
    if (microphoneActive)
      active.push("microphone");
    if (cameraActive)
      active.push("camera");
    if (screensharingActive)
      active.push("screensharing");
    return active.length ? `Privacy active: ${active.join(", ")}` : "No privacy concerns detected";
  }
}
