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
  property bool enabled: active
  property string focusedOutput: ""
  property var groupBoundaries: []
  property var monitors: []
  property var outputsOrder: []
  property int previousWorkspace: 1
  property var specialWorkspaces: []
  property var workspaces: []

  function focusWorkspaceByIndex(index) {
    if (enabled)
      Hyprland.dispatch("workspace " + index);
  }
  function focusWorkspaceByObject(ws) {
    if (ws)
      focusWorkspaceByIndex(ws.id);
  }
  function recompute() {
    try {
      const workspaceList = Hyprland.workspaces?.values || Hyprland.workspaces || [];
      const monitorList = Hyprland.monitors?.values || Hyprland.monitors || [];

      hyprWs.monitors = monitorList;

      const focusedMonitor = Hyprland.focusedMonitor || monitorList.find(monitor => monitor.focused);
      hyprWs.focusedOutput = focusedMonitor ? focusedMonitor.name : "";

      if (monitorList.length > 0) {
        hyprWs.outputsOrder = monitorList.slice().sort((left, right) => {
          if (focusedMonitor && left.name === focusedMonitor.name)
            return -1;
          if (focusedMonitor && right.name === focusedMonitor.name)
            return 1;
          return left.name.localeCompare(right.name);
        }).map(monitor => monitor.name);
      }

      const workspaceMap = workspaceList.reduce((map, ws) => {
        map[ws.id] = ws;
        return map;
      }, {});

      hyprWs.workspaces = Array.from({
        length: 10
      }, (_unused, index) => {
        const workspaceId = index + 1;
        const workspaceEntry = workspaceMap[workspaceId];
        return {
          id: workspaceId,
          focused: !!workspaceEntry?.focused,
          populated: !!workspaceEntry,
          output: workspaceEntry ? workspaceEntry.monitor : ""
        };
      });

      hyprWs.specialWorkspaces = workspaceList.filter(ws => ws.id < 0);

      const focusedWorkspace = workspaceList.find(ws => ws.focused && ws.id > 0);
      if (focusedWorkspace && focusedWorkspace.id !== hyprWs.currentWorkspace) {
        hyprWs.previousWorkspace = hyprWs.currentWorkspace;
        hyprWs.currentWorkspace = focusedWorkspace.id;
      }

      let accumulated = 0;
      hyprWs.groupBoundaries = hyprWs.outputsOrder.reduce((bounds, output) => {
        const count = hyprWs.workspaces.filter(ws => ws.output === output).length;
        accumulated += count;
        if (accumulated > 0 && accumulated < hyprWs.workspaces.length)
          bounds.push(accumulated);
        return bounds;
      }, []);
    } catch (e) {
      Logger.log("HyprWs", "Recompute error: " + e);
    }
  }
  function refresh() {
    if (enabled)
      recompute();
  }
  function toggleSpecial(name) {
    if (enabled && name)
      Hyprland.dispatch("togglespecialworkspace " + name);
  }

  Component.onCompleted: {
    if (enabled) {
      Hyprland.refreshMonitors();
      Hyprland.refreshWorkspaces();
      Qt.callLater(recompute);
    }
  }
  onActiveChanged: {
    if (active) {
      Hyprland.refreshMonitors();
      Hyprland.refreshWorkspaces();
      Qt.callLater(recompute);
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
  onEnabledChanged: if (enabled) {
    Hyprland.refreshMonitors();
    Hyprland.refreshWorkspaces();
    Qt.callLater(recompute);
  }

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
      if (evt.name === "activespecial") {
        hyprWs.activeSpecial = evt.data?.split(",")[0] || "";
        hyprWs.recompute();
      } else if (["workspace", "destroyworkspace", "createworkspace"].includes(evt.name)) {
        if (evt.name === "workspace") {
          const args = evt.parse(2) || evt.data?.split(",") || [];
          const newId = parseInt(args[0]);
          if (newId && newId !== hyprWs.currentWorkspace) {
            hyprWs.previousWorkspace = hyprWs.currentWorkspace;
            hyprWs.currentWorkspace = newId;
          }
          if (newId > 0)
            hyprWs.activeSpecial = "";
        }
        hyprWs.recompute();
      }
    }

    enabled: hyprWs.enabled
    target: enabled ? Hyprland : null
  }
}
