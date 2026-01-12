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
  readonly property int debounceMs: 50
  property bool enabled: MainService.ready && MainService.currentWM === "hyprland"
  property string focusedOutput: Hyprland.focusedMonitor?.name ?? ""
  property var groupBoundaries: []
  property var outputsOrder: []
  property int previousWorkspace: 1
  property var specialWorkspaces: []
  readonly property int startupDelayMs: 500
  property var workspaces: []

  function focusWorkspaceByIndex(idx: int): void {
    if (enabled && idx > 0)
      Hyprland.dispatch(`workspace ${idx}`);
  }

  function focusWorkspaceByWs(ws: var): void {
    if (ws?.id)
      focusWorkspaceByIndex(ws.id);
  }

  function recompute(): void {
    const wsValues = Array.from(Hyprland.workspaces.values);
    const monValues = Array.from(Hyprland.monitors.values);
    const focusedName = focusedOutput;

    const sortedMons = monValues.sort((a, b) => {
      const aName = a?.name ?? "";
      const bName = b?.name ?? "";
      return aName === focusedName ? -1 : bName === focusedName ? 1 : aName.localeCompare(bName);
    });

    const newOutputsOrder = sortedMons.map(m => m?.name ?? "");
    const specials = [];
    const regular = [];
    const counts = new Map();
    let focusedWs = null;

    for (const w of wsValues) {
      if (w.id <= 0) {
        specials.push({
          name: w?.name ?? `special:${w.id}`
        });
        continue;
      }

      const outputName = w.monitor?.name ?? "";
      const windows = w?.lastIpcObject?.windows ?? 0;

      const ws = {
        id: w.id,
        idx: w.id,
        focused: w.focused,
        populated: windows > 0,
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

    if (focusedWs.id !== currentWorkspace) {
      root.previousWorkspace = currentWorkspace;
      root.currentWorkspace = focusedWs.id;
    }

    // Compute group boundaries
    const bounds = [];
    let acc = 0;
    for (const out of newOutputsOrder) {
      acc += counts.get(out) ?? 0;
      if (acc > 0 && acc < regular.length)
        bounds.push(acc);
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
      previousWorkspace = 1;
    }
  }

  Timer {
    id: _debounceTimer

    interval: root.debounceMs
    repeat: false

    onTriggered: root.recompute()
  }

  Timer {
    id: _startupKick

    interval: root.startupDelayMs

    onTriggered: root.refresh()
  }

  Connections {
    function onFocusedMonitorChanged(): void {
      root.recomputeDebounced();
    }

    function onRawEvent(evt: var): void {
      const eventName = evt?.name ?? "";
      const eventData = evt?.data ?? "";

      switch (eventName) {
      case "activespecial":
        root.activeSpecial = eventData ? eventData.split(",")[0] : "";
        break;
      case "workspace":
      case "createworkspace":
      case "destroyworkspace":
      case "openwindow":
      case "closewindow":
      case "movewindow":
        Hyprland.refreshWorkspaces();
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
