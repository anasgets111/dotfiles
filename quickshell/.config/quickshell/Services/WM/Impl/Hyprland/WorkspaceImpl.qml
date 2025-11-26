pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Services
import qs.Services.Utils

Singleton {
  id: root

  property string activeSpecial: ""
  property int currentWorkspace: 1
  property int currentWorkspaceId: 1
  property bool enabled: MainService.ready && MainService.currentWM === "hyprland"
  property string focusedOutput: ""
  property var groupBoundaries: []
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

  function recompute() {
    try {
      const wsList = Hyprland.workspaces?.values || Hyprland.workspaces || [];
      const monList = Hyprland.monitors?.values || Hyprland.monitors || [];
      const focusedMon = Hyprland.focusedMonitor || monList.find(m => m.focused);

      root.focusedOutput = focusedMon?.name || "";
      root.outputsOrder = monList.length ? monList.slice().sort((l, r) => {
        if (l.name === root.focusedOutput)
          return -1;
        if (r.name === root.focusedOutput)
          return 1;
        return l.name.localeCompare(r.name);
      }).map(m => m.name) : [];

      root.specialWorkspaces = wsList.filter(w => w.id < 0);
      const newWorkspaces = wsList.filter(w => w.id > 0).map(w => {
        const winCount = w.lastIpcObject?.windows;
        return {
          id: w.id,
          focused: !!w.focused,
          populated: typeof winCount === "number" ? winCount > 0 : (!!w.hasFullscreen || !!w.focused),
          output: w.monitor?.name || (typeof w.monitor === "string" ? w.monitor : "")
        };
      }).sort((a, b) => a.id - b.id);
      root.workspaces = newWorkspaces;

      const focusedWs = wsList.find(w => w.id > 0 && w.focused);
      if (focusedWs?.id && focusedWs.id !== root.currentWorkspace) {
        root.previousWorkspace = root.currentWorkspace;
        root.currentWorkspace = root.currentWorkspaceId = focusedWs.id;
      }

      // Boundary calculation
      const counts = new Map();
      for (const w of newWorkspaces)
        counts.set(w.output || "", (counts.get(w.output || "") || 0) + 1);
      let acc = 0;
      root.groupBoundaries = root.outputsOrder.reduce((bounds, out) => {
        acc += counts.get(out) || 0;
        if (acc > 0 && acc < newWorkspaces.length)
          bounds.push(acc);
        return bounds;
      }, []);
    } catch (e) {
      Logger.log("HyprWs", "Recompute error: " + e);
    }
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

  Component.onCompleted: {
    if (enabled)
      refresh();
    _startupKick.start();
  }
  Component.onDestruction: {
    _startupKick.stop();
  }
  onEnabledChanged: {
    if (enabled) {
      refresh();
    } else {
      workspaces = specialWorkspaces = outputsOrder = groupBoundaries = [];
      activeSpecial = focusedOutput = "";
      currentWorkspace = currentWorkspaceId = previousWorkspace = 1;
    }
  }

  Connections {
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

    enabled: root.enabled
    target: enabled ? Hyprland : null
  }

  Timer {
    id: _startupKick

    interval: 200
    repeat: false

    onTriggered: if (root.enabled)
      root.refresh()
  }
}
