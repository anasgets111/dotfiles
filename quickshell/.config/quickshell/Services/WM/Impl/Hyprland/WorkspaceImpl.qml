pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Hyprland
import qs.Services
import qs.Services.Utils

Singleton {
  id: hyprWs

  readonly property bool active: MainService.ready && MainService.currentWM === "hyprland"
  property string activeSpecial: ""
  property int currentWorkspace: 1
  property int currentWorkspaceId: 1
  property bool enabled: active
  property string focusedOutput: ""
  property var groupBoundaries: []
  property var monitors: []
  property var outputsOrder: []
  property int previousWorkspace: 1
  property var specialWorkspaces: []
  property var workspaces: [] // [{ id, focused, populated, output }], id > 0 only

  function focusWorkspaceByIndex(index) {
    if (enabled && index)
      Hyprland.dispatch("workspace " + index);
  }
  function focusWorkspaceByObject(ws) {
    if (enabled && ws && ws.id)
      focusWorkspaceByIndex(ws.id);
  }
  function recompute() {
    try {
      const wsList = Hyprland.workspaces?.values || Hyprland.workspaces || [];
      const monList = Hyprland.monitors?.values || Hyprland.monitors || [];

      hyprWs.monitors = monList;

      const focusedMon = Hyprland.focusedMonitor || monList.find(m => m.focused);
      const newFocusedOutput = focusedMon ? focusedMon.name : "";
      if (newFocusedOutput !== hyprWs.focusedOutput)
        hyprWs.focusedOutput = newFocusedOutput;

      if (monList.length > 0) {
        const prevOrder = hyprWs.outputsOrder.join("|");
        const newOrder = monList.slice().sort((l, r) => {
          if (focusedMon && l.name === focusedMon.name)
            return -1;
          if (focusedMon && r.name === focusedMon.name)
            return 1;
          return l.name.localeCompare(r.name);
        }).map(m => m.name);
        if (newOrder.join("|") !== prevOrder)
          hyprWs.outputsOrder = newOrder;
      } else {
        hyprWs.outputsOrder = [];
      }

      // Only real (positive) workspaces; include output and focused flags
      const positive = wsList.filter(w => typeof w.id === "number" && w.id > 0);
      const specials = wsList.filter(w => typeof w.id === "number" && w.id < 0);
      hyprWs.specialWorkspaces = specials;

      // Hypr workspace objects typically: { id, name, monitor, windows, hasfullscreen, ... , focused }
      // Map monitor object to name; compute populated from windows count if available.
      const newWorkspaces = positive.map(w => {
        let windowsCount = undefined;
        try {
          windowsCount = w.lastIpcObject?.windows;
        } catch (_)
        // lastIpcObject may be undefined until a refresh cycles in
        {}
        const outputName = (w.monitor && w.monitor.name) ? w.monitor.name : (typeof w.monitor === "string" ? w.monitor : "");
        return {
          id: w.id,
          focused: !!w.focused,
          populated: (typeof windowsCount === "number") ? (windowsCount > 0) : (!!w.hasFullscreen || !!w.focused),
          output: outputName
        };
      }).sort((a, b) => a.id - b.id);

      hyprWs.workspaces = newWorkspaces;

      const focusedWs = positive.find(w => w.focused);
      if (focusedWs) {
        const newId = focusedWs.id;
        if (newId && newId !== hyprWs.currentWorkspace) {
          hyprWs.previousWorkspace = hyprWs.currentWorkspace;
          hyprWs.currentWorkspace = newId;
          hyprWs.currentWorkspaceId = newId;
          // leaving special if we go to positive
          if (hyprWs.activeSpecial && newId > 0)
            hyprWs.activeSpecial = "";
        }
      } else
      // No focused positive workspace reported; if activeSpecial exists, keep it, else keep current
      {}

      // Compute group boundaries based on outputsOrder and actual workspaces
      let acc = 0;
      const total = newWorkspaces.length;
      const bounds = [];
      hyprWs.outputsOrder.forEach(out => {
        const count = newWorkspaces.filter(w => w.output === out).length;
        acc += count;
        if (acc > 0 && acc < total)
          bounds.push(acc);
      });
      hyprWs.groupBoundaries = bounds;
    } catch (e) {
      Logger.log("HyprWs", "Recompute error: " + e);
    }
  }
  function refresh() {
    if (!enabled)
      return;
    Hyprland.refreshMonitors();
    Hyprland.refreshWorkspaces();
    Qt.callLater(recompute);
  }
  function toggleSpecial(name) {
    if (enabled && name)
      Hyprland.dispatch("togglespecialworkspace " + name);
  }

  Component.onCompleted: {
    if (enabled)
      refresh();
    // Perform a second, delayed refresh to ensure windows count and monitors settle after startup
    _startupKick.start();
  }
  onActiveChanged: {
    if (active) {
      refresh();
    } else {
      workspaces = [];
      specialWorkspaces = [];
      activeSpecial = "";
      currentWorkspace = 1;
      previousWorkspace = 1;
      focusedOutput = "";
      outputsOrder = [];
      groupBoundaries = [];
      monitors = [];
    }
  }
  onEnabledChanged: if (enabled)
    refresh()

  Connections {
    function onFocusedMonitorChanged() {
      if (!enabled)
        return;
      hyprWs.focusedOutput = Hyprland.focusedMonitor?.name || "";
      hyprWs.recompute();
    }
    function onRawEvent(evt) {
      if (!enabled || !evt?.name)
        return;

      // Known Hyprland events: workspace, createworkspace, destroyworkspace,
      // activespecial, closespecial, focusedmon, monitorremoved, monitoradded...
      switch (evt.name) {
      case "activespecial":
        {
          const name = evt.data?.split(",")[0] || "";
          hyprWs.activeSpecial = name;
          // focus may have changed; recompute to sync outputs/workspaces
          hyprWs.recompute();
          break;
        }
      case "closespecial":
      case "specialworkspace":
        {
          // depending on compositor version
          hyprWs.activeSpecial = "";
          hyprWs.recompute();
          break;
        }
      case "workspace":
      case "createworkspace":
      case "destroyworkspace":
        {
          // Instead of trusting evt payload, refresh and recompute for correctness
          Hyprland.refreshWorkspaces();
          Qt.callLater(hyprWs.recompute);
          break;
        }
      case "focusedmon":
      case "monitoradded":
      case "monitorremoved":
        {
          Hyprland.refreshMonitors();
          Qt.callLater(hyprWs.recompute);
          break;
        }
      }
    }

    enabled: hyprWs.enabled
    target: enabled ? Hyprland : null
  }

  // One-shot kick to stabilize initial state after load
  Timer {
    id: _startupKick
    interval: 200
    running: false
    repeat: false
    onTriggered: if (hyprWs.enabled)
      hyprWs.refresh()
  }
}
