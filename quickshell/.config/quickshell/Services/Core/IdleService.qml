pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Core

Singleton {
  id: root

  // Minimal ref-count inhibitor for programmatic holds (e.g., video playback)
  property int _holdCount: 0
  property var _reasons: ({})
  property alias enabled: properties.enabled
  property alias videoAutoEnabled: properties.videoAutoEnabled
  property alias videoInhibitReason: properties.videoInhibitReason
  property var _videoToken: null

  function acquire(reason) {
    const r = String(reason || "");
    if (r && !_reasons[r])
      _reasons[r] = 0;
    if (r)
      _reasons[r] = _reasons[r] + 1;
    _holdCount = _holdCount + 1;
    return {
      token: Math.random().toString(36).slice(2),
      reason: r
    };
  }
  function release(token) {
    // token is opaque; we only decrement once per call
    if (_holdCount > 0)
      _holdCount = _holdCount - 1;
  }
  function toggle() {
    if (properties.enabled) {
      properties.enabled = false;
    } else {
      properties.enabled = true;
    }
  }

  PersistentProperties {
    id: properties

    property bool enabled: false
    // When true, automatically inhibit idle while video is detected playing
    property bool videoAutoEnabled: true
    // Reason string for systemd-inhibit when auto video is active
    property string videoInhibitReason: "Video playback"

    reloadableId: "Caffeine"
  }
  Process {
    id: process

    command: ["sh", "-c", "systemd-inhibit --what=idle --who=Quickshell --why='Idle inhibited' --mode=block sleep infinity"]
    running: properties.enabled || (root._holdCount > 0)
  }

  Connections {
    target: MediaService

    function onAnyVideoPlayingChanged() {
      if (properties.videoAutoEnabled && MediaService.anyVideoPlaying) {
        if (!root._videoToken)
          root._videoToken = root.acquire(properties.videoInhibitReason);
      } else if (root._videoToken) {
        root.release(root._videoToken);
        root._videoToken = null;
      }
    }
  }

  // Ensure correct initial state on startup
  Component.onCompleted: {
    if (properties.videoAutoEnabled && MediaService.anyVideoPlaying && !root._videoToken)
      root._videoToken = root.acquire(properties.videoInhibitReason);
  }
}
