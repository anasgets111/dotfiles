pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Services

Singleton {
  id: root

  property int _bootSyncCount: 0
  readonly property var _focusedMonitor: _hyprctlMonitors.find(m => m.focused)
  property var _hyprctlMonitors: []
  property var _hyprctlWorkspaces: []
  readonly property var _layoutState: {
    _updateTick;
    return enabled ? _calcLayout() : ({
        ws: [],
        special: [],
        out: [],
        bounds: []
      });
  }
  readonly property var _structuralEvents: ["workspace", "workspacev2", "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2", "focusedmon", "monitoradded", "monitoraddedv2", "monitorremoved", "moveworkspace", "openwindow", "closewindow", "movewindow"]
  property int _updateTick: 0
  property string activeSpecial: ""
  readonly property int currentWorkspace: _focusedMonitor?.activeWorkspace?.id ?? 1
  readonly property bool enabled: MainService.ready && MainService.currentWM === "hyprland"
  readonly property string focusedOutput: _focusedMonitor?.name ?? ""
  readonly property var groupBoundaries: _layoutState.bounds
  readonly property var outputsOrder: _layoutState.out
  readonly property var specialWorkspaces: _layoutState.special
  readonly property var workspaces: _layoutState.ws

  function _calcLayout(): var {
    const outOrder = _hyprctlMonitors.sort((a, b) => (b.focused - a.focused) || a.name.localeCompare(b.name)).map(m => m.name);

    const regular = [];
    const special = [];
    const counts = new Map();

    for (const w of _hyprctlWorkspaces) {
      if (w.id < -1) {
        special.push({
          name: w.name
        });
      } else if (w.id > 0) {
        const outName = w.monitor ?? "";
        regular.push({
          id: w.id,
          idx: w.id,
          focused: w.id === currentWorkspace,
          populated: (w.windows ?? 0) > 0,
          output: outName
        });
        if (outName)
          counts.set(outName, (counts.get(outName) ?? 0) + 1);
      }
    }

    regular.sort((a, b) => a.id - b.id);

    const bounds = [];
    let acc = 0;
    const total = regular.length;
    for (const out of outOrder) {
      acc += counts.get(out) ?? 0;
      if (acc > 0 && acc < total)
        bounds.push(acc);
    }

    return {
      ws: regular,
      special,
      out: outOrder,
      bounds
    };
  }

  function _onDataReceived(): void {
    if (_hyprctlWorkspaces.length && _hyprctlMonitors.length && _bootSyncCount++ < 2) {
      Qt.callLater(_refresh);
    }
  }

  function _parseJSON(text: string, onSuccess): void {
    try {
      onSuccess(JSON.parse(text));
      _updateTick++;
      _onDataReceived();
    } catch (e) {
      console.error("[WorkspaceImpl] Parse error:", e);
    }
  }

  function _refresh(): void {
    if (enabled) {
      if (!wsProc.running)
        wsProc.running = true;
      if (!monProc.running)
        monProc.running = true;
    }
  }

  function focusWorkspaceByIndex(idx: int): void {
    if (enabled && idx > 0)
      Hyprland.dispatch(`workspace ${idx}`);
  }

  function toggleSpecial(name: string): void {
    if (enabled && name)
      Hyprland.dispatch(`togglespecialworkspace ${name}`);
  }

  onEnabledChanged: if (enabled) {
    _bootSyncCount = 0;
    _refresh();
  }

  Process {
    id: wsProc

    command: ["hyprctl", "-j", "workspaces"]

    stdout: StdioCollector {
      id: wsCollector

    }

    onExited: code => {
      if (code === 0 && wsCollector.text) {
        root._parseJSON(wsCollector.text, data => root._hyprctlWorkspaces = data);
      }
    }
  }

  Process {
    id: monProc

    command: ["hyprctl", "-j", "monitors"]

    stdout: StdioCollector {
      id: monCollector

    }

    onExited: code => {
      if (code === 0 && monCollector.text) {
        root._parseJSON(monCollector.text, mons => {
          root._hyprctlMonitors = mons;
          root.activeSpecial = root._focusedMonitor?.specialWorkspace?.name ?? "";
        });
      }
    }
  }

  Connections {
    function onReloadCompleted() {
      root._bootSyncCount = 0;
      root._refresh();
    }

    enabled: root.enabled
    target: Quickshell
  }

  Connections {
    function onRawEvent(event: var): void {
      if (event.name === "activespecialv2") {
        root.activeSpecial = event.data.split(",")[1] || "";
      }
      if (root._bootSyncCount >= 2 && root._structuralEvents.includes(event.name)) {
        root._refresh();
      }
    }

    enabled: root.enabled
    target: Hyprland
  }
}
