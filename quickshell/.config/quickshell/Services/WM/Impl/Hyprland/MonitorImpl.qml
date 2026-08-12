pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Services.Utils

Singleton {
  id: root

  signal featuresChanged

  // Live monitorv2 field mutation is unverified on the Hyprland host.
  readonly property var controls: []
  readonly property var _transforms: ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]
  function _bitDepthFromFormat(format: string): var {
    return /2101010|P010/i.test(format) ? 10 : /P012/i.test(format) ? 12 : /16161616|P016/i.test(format) ? 16 : /8888/i.test(format) ? 8 : undefined;
  }
  function fetchFeatures(name: string, callback: var): void {
    const state = Utils.toArray(Hyprland.monitors?.values).find(monitor => monitor?.name === name)?.lastIpcObject;
    if (!state) {
      callback(null);
      return;
    }

    const modeKeys = Utils.toArray(state.availableModes).map(modeText => {
      const match = modeText.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
      return match ? Utils.modeKey(parseInt(match[1]), parseInt(match[2]), parseFloat(match[3])) : "";
    });
    const scale = typeof state.scale === "number" && state.scale > 0 ? state.scale : 1;
    const rotated = [1, 3, 5, 7].includes(state.transform);

    callback({
      colorMode: state.colorManagementPreset,
      currentModeKey: Utils.modeKey(state.width, state.height, state.refreshRate),
      displayModel: state.model,
      logicalHeight: (rotated ? state.width : state.height) / scale,
      logicalWidth: (rotated ? state.height : state.width) / scale,
      logicalX: state.x,
      logicalY: state.y,
      maxBpc: _bitDepthFromFormat(String(state.currentFormat ?? "")),
      modeKeys,
      scale,
      transformMode: _transforms[state.transform] ?? "normal",
      vrrMode: state.vrr ? "on" : "off"
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
