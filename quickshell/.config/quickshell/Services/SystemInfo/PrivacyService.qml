pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
  id: root

  readonly property var cameraMediaClasses: ["stream/input/video", "video/source", "stream/output/video"]

  readonly property var virtualMicRegex: /cava|monitor|system/

  readonly property var collaborationAppRegex: /slack|zoom|discord|vesktop|teams|microsoft\s+teams|meet|google\s+meet|hangouts|skype|webex|jitsi|gotomeeting|go-to-meeting|gotowebinar|bluejeans|whereby|loom|huddle|livestream|youtube\s+live|twitch|obs|vdo\.ninja|webrtc|stage|presenter|broadcast|streamyard/

  readonly property var screenshareContextRegex: /xdg-desktop-portal|xdpw|screencast|screen|screenshare|share|sharing|desktop|present|presenting|presentation|presenter|portal|capture|captur|record|recording|cast|casting|display|mirror|mirroring|broadcast|broadcasting|gnome\s+shell|kwin|obs|livestream|live\s*stream|streaming|window|monitor|surface|projector|whiteboard|stage|slides|airplay|remote\s*desktop|webrtc/

  readonly property var collaborationShareContextRegex: /meeting|call|conference|share|screen|screenshare|desktop|window|monitor|stage|present|presentation|record|stream|broadcast|live|cast|slides|whiteboard|portal/

  readonly property var secondaryScreenshareHintsRegex: /portal|window|monitor|display|surface|share|screen|desktop|present|presentation|captur|record|cast|stream|broadcast|stage|slides|whiteboard/

  readonly property var screenshareBrowserRegex: /zen|firefox|chrome|chromium|brave|vivaldi|opera|edge|portal|xdpw|meet|google|desktop|share|stream|cast|record|obs|gnome|kwin/

  function normalize(value) {
    if (value === null || value === undefined) {
      return "";
    }

    return String(value).toLowerCase().trim();
  }

  function pipewireNodes() {
    if (!Pipewire.ready) {
      return [];
    }

    const nodes = Pipewire.nodes?.values;
    return Array.isArray(nodes) ? nodes : [];
  }

  function combineNormalized(parts) {
    return parts.map(part => normalize(part)).join(" ").trim();
  }

  readonly property bool microphoneActive: {
    for (const node of pipewireNodes()) {
      if (!node) {
        continue;
      }

      if ((node.type & PwNodeType.AudioInStream) !== PwNodeType.AudioInStream) {
        continue;
      }

      if (looksLikeSystemVirtualMic(node)) {
        continue;
      }

      if (node.audio && node.audio.muted) {
        continue;
      }

      return true;
    }

    return false;
  }

  PwObjectTracker {
    objects: Pipewire.nodes?.values?.filter(node => node.audio && !node.isStream) ?? []
  }

  readonly property bool cameraActive: {
    for (const node of pipewireNodes()) {
      if (!node) {
        continue;
      }

      const properties = node.properties || {};
      const mediaClass = normalize(properties["media.class"]);

      if (!root.cameraMediaClasses.includes(mediaClass)) {
        continue;
      }

      const state = nodeStateName(node);

      if (propertyTruthy(properties["stream.is-live"]) || state === "running") {
        return true;
      }
    }

    return false;
  }

  readonly property bool screensharingActive: {
    const screencastCandidates = [];

    for (const node of pipewireNodes()) {
      if (!node) {
        continue;
      }

      const properties = node.properties || {};
      const mediaClass = normalize(properties["media.class"]);
      const state = nodeStateName(node);
      const looksScreencastNode = looksLikeScreencast(node);
      const streamLive = propertyTruthy(properties["stream.is-live"]);
      const videoSource = (node.type & PwNodeType.VideoSource) === PwNodeType.VideoSource;

      if (looksScreencastNode) {
        screencastCandidates.push({
          ready: node.ready === undefined ? true : node.ready,
          state,
          streamLive,
          app: normalize(properties["application.name"] || properties["application.id"] || properties["application.process.binary"] || node.name)
        });
      }

      if (looksScreencastNode && (videoSource || (mediaClass.includes("video") && (streamLive || state === "running")))) {
        return true;
      }

      if (mediaClass.includes("audio")) {
        const appName = normalize(properties["application.name"]);
        const combinedAudioContext = combineNormalized([properties["media.name"], properties["application.name"], properties["node.description"]]);

        let audioLooksLikeScreencast = looksScreencastNode || root.hasScreenshareContext(combinedAudioContext) || appName === "obs";

        if (!audioLooksLikeScreencast && root.containsCollaborationApp(combinedAudioContext)) {
          const audioSecondaryContext = combineNormalized([properties["media.role"], properties["pipewire.access.portal.session"], properties["pipewire.access.portal.app-id"]]);
          if (root.hasScreenshareContext(audioSecondaryContext) || root.containsCollaborationApp(audioSecondaryContext)) {
            audioLooksLikeScreencast = true;
          }
        }

        if (audioLooksLikeScreencast && (streamLive || state === "running") && !(node.audio && node.audio.muted)) {
          return true;
        }
      }
    }

    if (screencastCandidates.length > 0) {
      const strongCandidate = screencastCandidates.find(candidate => candidate.streamLive || candidate.state === "running" || !candidate.ready);
      const browserCandidate = screencastCandidates.find(candidate => root.screenshareBrowserRegex.test(candidate.app) || root.containsCollaborationApp(candidate.app));
      if (strongCandidate && browserCandidate) {
        return true;
      }
    }

    return false;
  }

  readonly property bool anyPrivacyActive: microphoneActive || cameraActive || screensharingActive

  function looksLikeSystemVirtualMic(node) {
    if (!node) {
      return false;
    }
    const combined = combineNormalized([node.name, node.properties["media.name"], node.properties["application.name"]]);
    return combined.search(/cava|monitor|system/) !== -1;
  }

  function containsCollaborationApp(text) {
    if (!text) {
      return false;
    }

    return root.collaborationAppRegex.test(normalize(text));
  }

  function hasScreenshareContext(text) {
    if (!text) {
      return false;
    }

    const normalized = normalize(text);

    if (root.screenshareContextRegex.test(normalized)) {
      return true;
    }

    if (root.containsCollaborationApp(normalized)) {
      return root.collaborationShareContextRegex.test(normalized);
    }

    return false;
  }

  function looksLikeScreencast(node) {
    if (!node) {
      return false;
    }
    const properties = node.properties || {};
    const combined = combineNormalized([properties["application.name"], properties["application.id"], properties["application.process.binary"], properties["application.icon-name"], node.name, properties["media.name"], properties["node.description"], properties["media.role"], properties["target.object"], properties["object.serial"]]);

    if (root.hasScreenshareContext(combined)) {
      return true;
    }

    if (!root.containsCollaborationApp(combined)) {
      return false;
    }

    const secondaryContext = combineNormalized([properties["media.class"], properties["media.role"], properties["node.description"], properties["media.name"], properties["target.object"], properties["pipewire.access.portal.session"], properties["pipewire.access.portal.app-id"]]);

    if (root.hasScreenshareContext(secondaryContext) || root.containsCollaborationApp(secondaryContext)) {
      return true;
    }

    return root.secondaryScreenshareHintsRegex.test(secondaryContext);
  }

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
    if (microphoneActive) {
      active.push("microphone");
    }
    if (cameraActive) {
      active.push("camera");
    }
    if (screensharingActive) {
      active.push("screensharing");
    }

    return active.length > 0 ? `Privacy active: ${active.join(", ")}` : "No privacy concerns detected";
  }

  function nodeStateName(node) {
    if (!node) {
      return "unknown";
    }

    if (node.state !== undefined) {
      const stateMap = {
        0: "error",
        1: "creating",
        2: "suspended",
        3: "idle",
        4: "running"
      };
      const mapped = stateMap[node.state];
      if (mapped !== undefined) {
        return mapped;
      }
      return String(node.state);
    }

    const properties = node.properties || {};
    const propState = properties["node.state"] || properties["pw.session.state"] || properties["session.state"];
    if (propState) {
      return String(propState).toLowerCase();
    }

    return "unknown";
  }

  function propertyTruthy(value) {
    if (value === null || value === undefined) {
      return false;
    }
    if (typeof value === "boolean") {
      return value;
    }
    if (typeof value === "number") {
      return value !== 0;
    }

    const normalized = String(value).trim().toLowerCase();
    return normalized === "true" || normalized === "1" || normalized === "yes" || normalized === "on";
  }
}
