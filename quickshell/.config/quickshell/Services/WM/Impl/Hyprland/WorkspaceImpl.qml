pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Services
import qs.Services.Utils

Singleton {
  id: root

  readonly property bool active: MainService.ready && MainService.currentWM === "hyprland"
  property bool enabled: active

  property string activeSpecial: ""
  property int currentWorkspace: 1
  property int currentWorkspaceId: 1
  property string focusedOutput: ""
  property var groupBoundaries: []
  property var monitors: []
  property var outputsOrder: []
  property int previousWorkspace: 1
  property var specialWorkspaces: []
  property var workspaces: []

  function focusWorkspaceByIndex(index) {
    if (enabled && index)
      Hyprland.dispatch("workspace " + index);
  }
  function focusWorkspaceByObject(ws) {
    if (enabled && ws?.id)
      focusWorkspaceByIndex(ws.id);
  }
  function refresh() {
    if (enabled) {
      Hyprland.refreshMonitors();
      Hyprland.refreshWorkspaces();
      Qt.callLater(recompute);
    }
  }
  function toggleSpecial(name) {
    if (enabled && name)
      Hyprland.dispatch("togglespecialworkspace " + name);
  }

  function recompute() {
    try {
      const wsList = Hyprland.workspaces?.values || Hyprland.workspaces || [];
      const monList = Hyprland.monitors?.values || Hyprland.monitors || [];
      root.monitors = monList;

      const focusedMon = Hyprland.focusedMonitor || monList.find(m => m.focused);
      const newFocusedOutput = focusedMon?.name || "";
      if (newFocusedOutput !== root.focusedOutput)
        root.focusedOutput = newFocusedOutput;

      if (monList.length > 0) {
        const prevOrder = root.outputsOrder.join("|");
        const newOrder = monList.slice().sort((l, r) => {
          if (focusedMon && l.name === focusedMon.name)
            return -1;
          if (focusedMon && r.name === focusedMon.name)
            return 1;
          return l.name.localeCompare(r.name);
        }).map(m => m.name);
        if (newOrder.join("|") !== prevOrder)
          root.outputsOrder = newOrder;
      } else {
        root.outputsOrder = [];
      }

      const positive = wsList.filter(w => typeof w.id === "number" && w.id > 0);
      const specials = wsList.filter(w => typeof w.id === "number" && w.id < 0);
      root.specialWorkspaces = specials;

      const newWorkspaces = positive.map(w => {
        let windowsCount;
        try {
          windowsCount = w.lastIpcObject?.windows;
        } catch (_) {}
        const outputName = w.monitor?.name || (typeof w.monitor === "string" ? w.monitor : "");
        return {
          id: w.id,
          focused: !!w.focused,
          populated: typeof windowsCount === "number" ? windowsCount > 0 : (!!w.hasFullscreen || !!w.focused),
          output: outputName
        };
      }).sort((a, b) => a.id - b.id);

      root.workspaces = newWorkspaces;

      const focusedWs = positive.find(w => w.focused);
      if (focusedWs) {
        const newId = focusedWs.id;
        if (newId && newId !== root.currentWorkspace) {
          root.previousWorkspace = root.currentWorkspace;
          root.currentWorkspace = newId;
          root.currentWorkspaceId = newId;
        }
      }

      let acc = 0;
      const total = newWorkspaces.length;
      const bounds = [];
      root.outputsOrder.forEach(out => {
        const count = newWorkspaces.filter(w => w.output === out).length;
        acc += count;
        if (acc > 0 && acc < total)
          bounds.push(acc);
      });
      root.groupBoundaries = bounds;
    } catch (e) {
      Logger.log("HyprWs", "Recompute error: " + e);
    }
  }

  Component.onCompleted: {
    if (enabled)
      refresh();
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
    enabled: root.enabled
    target: enabled ? Hyprland : null

    function onFocusedMonitorChanged() {
      if (!enabled)
        return;
      root.focusedOutput = Hyprland.focusedMonitor?.name || "";
      root.recompute();
    }
    function onRawEvent(evt) {
      if (!enabled || !evt?.name)
        return;
      switch (evt.name) {
      case "activespecial":
        const specialName = evt.data?.split(",")[0] || "";
        root.activeSpecial = specialName;
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
  }

  Timer {
    id: _startupKick
    interval: 200
    repeat: false
    onTriggered: if (root.enabled)
      root.refresh()
  }

  Component.onDestruction: {
    _startupKick.stop();
  }
}
