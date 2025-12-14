pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Services

Singleton {
  id: root

  property string activeSpecial: ""
  property int currentWorkspace: 1
  property int currentWorkspaceId: 1
  property bool enabled: MainService.ready && MainService.currentWM === "hyprland"
  property string focusedOutput: Hyprland.focusedMonitor?.name ?? ""
  property var groupBoundaries: []
  property var outputsOrder: []
  property int previousWorkspace: 1
  property var specialWorkspaces: []
  property var workspaces: []

  function focusWorkspaceByIndex(idx: int): void {
    if (enabled && idx > 0)
      Hyprland.dispatch(`workspace ${idx}`);
  }

  function focusWorkspaceByWs(ws: var): void {
    if (ws?.id)
      focusWorkspaceByIndex(ws.id);
  }

  function getOccupiedWorkspaceIds(): var {
    const occupied = {};
    const toplevels = Hyprland.toplevels?.values ?? [];

    for (const toplevel of toplevels) {
      const wsId = toplevel?.workspace?.id;
      if (typeof wsId === "number" && wsId > 0)
        occupied[wsId] = true;
    }

    return occupied;
  }

  function recompute(): void {
    const wsList = Array.from(Hyprland.workspaces.values);
    const monList = Array.from(Hyprland.monitors.values);
    const focusedName = focusedOutput;
    const occupiedIds = getOccupiedWorkspaceIds();

    // Sort monitors: focused first, then alphabetical (non-mutating)
    const sortedMons = [...monList].sort((a, b) => {
      const aName = a?.name ?? "";
      const bName = b?.name ?? "";
      if (aName === focusedName)
        return -1;
      if (bName === focusedName)
        return 1;
      return aName.localeCompare(bName);
    });

    const newOutputsOrder = sortedMons.map(m => m?.name ?? "");
    const specials = [];
    const regular = [];
    const counts = new Map();
    let focusedWs = null;

    for (const w of wsList) {
      if (w.id <= 0) {
        specials.push(w);
        continue;
      }

      const outputName = w.monitor?.name ?? "";
      const populated = occupiedIds[w.id] === true;

      const ws = {
        id: w.id,
        idx: w.id,
        focused: w.focused,
        populated,
        output: outputName
      };

      regular.push(ws);
      counts.set(outputName, (counts.get(outputName) ?? 0) + 1);

      if (w.focused)
        focusedWs = ws;
    }

    regular.sort((a, b) => a.idx - b.idx);

    root.outputsOrder = newOutputsOrder;
    root.specialWorkspaces = specials;
    root.workspaces = regular;

    if (focusedWs && focusedWs.id !== currentWorkspace) {
      root.previousWorkspace = currentWorkspace;
      root.currentWorkspace = focusedWs.id;
      root.currentWorkspaceId = focusedWs.id;
    }

    // Compute group boundaries for multi-monitor setups
    const bounds = [];
    if (regular.length > 0) {
      let acc = 0;
      for (const out of newOutputsOrder) {
        acc += counts.get(out) ?? 0;
        if (acc > 0 && acc < regular.length)
          bounds.push(acc);
      }
    }
    root.groupBoundaries = bounds;
  }

  function recomputeDebounced(): void {
    _debounceTimer.restart();
  }

  function refresh(): void {
    if (!enabled)
      return;
    Hyprland.refreshMonitors();
    Hyprland.refreshWorkspaces();
    Hyprland.refreshToplevels();
    recomputeDebounced();
  }

  function toggleSpecial(name: string): void {
    if (enabled && name)
      Hyprland.dispatch(`togglespecialworkspace ${name}`);
  }

  Component.onCompleted: {
    if (enabled)
      _startupKick.start();
  }
  onEnabledChanged: {
    if (enabled) {
      refresh();
    } else {
      workspaces = [];
      specialWorkspaces = [];
      outputsOrder = [];
      groupBoundaries = [];
      activeSpecial = "";
      currentWorkspace = 1;
      currentWorkspaceId = 1;
      previousWorkspace = 1;
    }
  }

  Timer {
    id: _debounceTimer

    interval: 50
    repeat: false

    onTriggered: root.recompute()
  }

  Timer {
    id: _startupKick

    interval: 200

    onTriggered: root.refresh()
  }

  // React to workspace ObjectModel changes
  Connections {
    function onValuesChanged(): void {
      root.recomputeDebounced();
    }

    enabled: root.enabled
    target: Hyprland.workspaces
  }

  // React to toplevel (window) ObjectModel changes
  Connections {
    function onValuesChanged(): void {
      root.recomputeDebounced();
    }

    enabled: root.enabled
    target: Hyprland.toplevels
  }

  // Handle Hyprland signals and raw events
  Connections {
    function onFocusedMonitorChanged(): void {
      root.recomputeDebounced();
    }

    function onRawEvent(evt: var): void {
      const eventName = evt?.name ?? "";
      const eventData = typeof evt?.data === "string" ? evt.data : "";

      switch (eventName) {
      case "activespecial":
        // Format: "specialname,monitorname" or empty when closing
        root.activeSpecial = eventData ? eventData.split(",")[0] : "";
        break;
      case "workspace":
      case "createworkspace":
      case "destroyworkspace":
        Hyprland.refreshWorkspaces();
        root.recomputeDebounced();
        break;
      case "openwindow":
      case "closewindow":
      case "movewindow":
        Hyprland.refreshToplevels();
        root.recomputeDebounced();
        break;
      case "monitoradded":
      case "monitorremoved":
        Hyprland.refreshMonitors();
        root.recomputeDebounced();
        break;
      }
    }

    enabled: root.enabled
    target: Hyprland
  }
}
