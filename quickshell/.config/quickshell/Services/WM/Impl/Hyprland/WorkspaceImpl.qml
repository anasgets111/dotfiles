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

  function focusWorkspaceByIndex(idx) {
    if (enabled && idx)
      Hyprland.dispatch("workspace " + idx);
  }

  function focusWorkspaceByWs(ws) {
    if (enabled && ws?.id)
      focusWorkspaceByIndex(ws.id);
  }

  function recompute() {
    const wsList = Array.from(Hyprland.workspaces.values);
    const monList = Array.from(Hyprland.monitors.values);

    // Sort monitors: focused first, then alphabetical by name
    const sortedMons = monList.sort((a, b) => {
      const aName = a?.name ?? "";
      const bName = b?.name ?? "";
      if (aName === focusedOutput)
        return -1;
      if (bName === focusedOutput)
        return 1;
      return aName.localeCompare(bName);
    });
    const outputsOrder = sortedMons.map(m => m.name);
    root.outputsOrder = outputsOrder;

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
      const winCount = w.lastIpcObject?.windows;
      const populated = typeof winCount === "number" ? winCount > 0 : (w.hasFullscreen || w.focused);
      const ws = {
        id: w.id,
        idx: w.id // Hyprland: idx equals id
        ,
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
    root.specialWorkspaces = specials;
    root.workspaces = regular;

    if (focusedWs && focusedWs.id !== currentWorkspace) {
      root.previousWorkspace = currentWorkspace;
      root.currentWorkspace = root.currentWorkspaceId = focusedWs.id;
    }

    const bounds = [];
    if (regular.length) {
      let acc = 0;
      for (const out of outputsOrder) {
        acc += counts.get(out) ?? 0;
        if (acc > 0 && acc < regular.length)
          bounds.push(acc);
      }
    }
    root.groupBoundaries = bounds;
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

  Component.onCompleted: if (enabled)
    _startupKick.start()
  onEnabledChanged: {
    if (enabled) {
      refresh();
    } else {
      workspaces = specialWorkspaces = outputsOrder = groupBoundaries = [];
      activeSpecial = "";
      currentWorkspace = currentWorkspaceId = previousWorkspace = 1;
    }
  }

  Connections {
    function onFocusedMonitorChanged() {
      root.recompute();
    }

    function onRawEvent(evt) {
      switch (evt.name) {
      case "activespecial":
        root.activeSpecial = evt.data?.split(",")[0] ?? "";
        root.recompute();
        break;
      case "closespecial":
      case "specialworkspace":
        root.activeSpecial = "";
        root.recompute();
        break;
      case "workspace":
      case "createworkspace":
      case "destroyworkspace":
        Hyprland.refreshWorkspaces();
        Qt.callLater(root.recompute);
        break;
      case "focusedmon":
      case "monitoradded":
      case "monitorremoved":
        Hyprland.refreshMonitors();
        Qt.callLater(root.recompute);
        break;
      }
    }

    enabled: root.enabled
    target: Hyprland
  }

  Timer {
    id: _startupKick

    interval: 200

    onTriggered: root.refresh()
  }
}
