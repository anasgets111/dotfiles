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
  // kept writable so facade Binding can override
  property bool enabled: active

  // live state
  property string activeSpecial: ""
  property int currentWorkspace: 1
  property int currentWorkspaceId: 1
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
    if (enabled && ws?.id)
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

      const positive = wsList.filter(w => typeof w.id === "number" && w.id > 0);
      const specials = wsList.filter(w => typeof w.id === "number" && w.id < 0);
      hyprWs.specialWorkspaces = specials;

      const newWorkspaces = positive.map(w => {
        let windowsCount;
        try {
          windowsCount = w.lastIpcObject?.windows;
        } catch (_) {}
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
          if (hyprWs.activeSpecial && newId > 0)
            hyprWs.activeSpecial = "";
        }
      }

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
    enabled: hyprWs.enabled
    target: enabled ? Hyprland : null

    function onFocusedMonitorChanged() {
      if (!enabled)
        return;
      hyprWs.focusedOutput = Hyprland.focusedMonitor?.name || "";
      hyprWs.recompute();
    }
    function onRawEvent(evt) {
      if (!enabled || !evt?.name)
        return;
      switch (evt.name) {
      case "activespecial":
        {
          const name = evt.data?.split(",")[0] || "";
          hyprWs.activeSpecial = name;
          hyprWs.recompute();
          break;
        }
      case "closespecial":
      case "specialworkspace":
        {
          hyprWs.activeSpecial = "";
          hyprWs.recompute();
          break;
        }
      case "workspace":
      case "createworkspace":
      case "destroyworkspace":
        {
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
      case "closespecial":
      case "specialworkspace":
        {
          hyprWs.activeSpecial = "";
          Hyprland.refreshWorkspaces();
          Qt.callLater(function () {
            hyprWs.recompute();
            Hyprland.dispatch("focuscurrentorlast"); // ensure focus returns to a real client
          });
          break;
        }
      }
    }
  }
  Timer {
    id: _specialDefocus
    interval: 80
    repeat: false
    onTriggered: if (hyprWs.enabled)
      Hyprland.dispatch("workspace " + (hyprWs.currentWorkspace || 1))
  }
  Timer {
    id: _startupKick
    interval: 200
    repeat: false
    onTriggered: if (hyprWs.enabled)
      hyprWs.refresh()
  }

  Component.onDestruction: {
    _specialDefocus.stop();
    _startupKick.stop();
  }
}
