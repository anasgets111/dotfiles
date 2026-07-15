pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
  id: root

  signal featuresChanged

  function _bitDepthFromFormat(format: string): var {
    if (/2101010|P010/i.test(format))
      return 10;
    if (/P012/i.test(format))
      return 12;
    if (/16161616|P016/i.test(format))
      return 16;
    if (/8888/i.test(format))
      return 8;
    return null;
  }
  function _findMonitor(name: string): var {
    const monitors = Hyprland.monitors?.values || [];
    return monitors.find(monitor => monitor?.name === name) || null;
  }
  function fetchFeatures(name: string, callback: var): void {
    const monitor = _findMonitor(name);
    if (!monitor) {
      callback(null);
      return;
    }

    const state = monitor.lastIpcObject ?? {};
    const modes = (state.availableModes || []).map(modeText => {
      const match = modeText.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
      return match ? {
        width: parseInt(match[1]),
        height: parseInt(match[2]),
        refreshRate: parseFloat(match[3])
      } : {
        raw: modeText
      };
    });

    const hdrActive = !!state.currentFormat && /2101010|P010|P012|PQ/i.test(state.currentFormat);
    const isMirror = !!state.mirrorOf && state.mirrorOf !== "none";

    callback({
      bitDepth: _bitDepthFromFormat(String(state.currentFormat ?? "")),
      fps: typeof state.refreshRate === "number" ? state.refreshRate : null,
      modes,
      vrr: {
        active: !!state.vrr
      },
      hdr: {
        active: hdrActive
      },
      mirror: isMirror
    });
  }

  Timer {
    id: featureRefreshDebounce

    interval: 50

    onTriggered: root.featuresChanged()
  }
  Connections {
    function onRawEvent(event: var): void {
      if (!["configreloaded", "fullscreen", "monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2"].includes(event?.name))
        return;
      Hyprland.refreshMonitors();
      featureRefreshDebounce.restart();
    }

    target: Hyprland
  }
}
