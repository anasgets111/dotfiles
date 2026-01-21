pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Services

Singleton {
  id: root

  readonly property var _emptyLayout: ({
      ws: [],
      special: [],
      out: [],
      bounds: []
    })
  property int _historyTracker: 1
  readonly property var _layoutState: enabled ? _calcLayout() : _emptyLayout
  property string activeSpecial: ""
  readonly property int currentWorkspaceId: Hyprland.focusedWorkspace?.id ?? 1
  readonly property bool enabled: MainService.ready && MainService.currentWM === "hyprland"
  readonly property string focusedOutput: Hyprland.focusedMonitor?.name ?? ""
  readonly property var groupBoundaries: _layoutState.bounds
  readonly property var outputsOrder: _layoutState.out
  property int previousWorkspace: 1
  readonly property var specialWorkspaces: _layoutState.special
  readonly property var workspaces: _layoutState.ws

  function _calcLayout(): var {
    const rawWs = Array.from(Hyprland.workspaces.values);
    const rawMons = Array.from(Hyprland.monitors.values);
    const outOrder = rawMons.sort((a, b) => (b.focused - a.focused) || a.name.localeCompare(b.name)).map(m => m.name);

    const regular = [];
    const special = [];
    const counts = new Map();

    for (const w of rawWs) {
      if (w.id < -1) {
        special.push({
          name: w.name
        });
        continue;
      }

      if (w.id <= 0)
        continue;

      const outName = w.monitor?.name ?? "";
      const winCount = w.toplevels?.size ?? w.lastIpcObject?.windows ?? 0;

      regular.push({
        id: w.id,
        focused: w.focused,
        populated: winCount > 0,
        output: outName
      });

      if (outName)
        counts.set(outName, (counts.get(outName) ?? 0) + 1);
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

  function focusWorkspaceByIndex(idx: int): void {
    if (enabled && idx > 0)
      Hyprland.dispatch(`workspace ${idx}`);
  }

  function toggleSpecial(name: string): void {
    if (enabled && name)
      Hyprland.dispatch(`togglespecialworkspace ${name}`);
  }

  Component.onCompleted: {
    if (enabled) {
      _historyTracker = currentWorkspaceId;
      previousWorkspace = currentWorkspaceId;
    }
  }
  onCurrentWorkspaceIdChanged: {
    if (currentWorkspaceId > 0 && currentWorkspaceId !== _historyTracker) {
      previousWorkspace = _historyTracker;
      _historyTracker = currentWorkspaceId;
      root.activeSpecial = "";
    }
  }

  Connections {
    function onRawEvent(event: var): void {
      if (event.name === "activespecialv2") {
        const parts = event.data.split(",");
        root.activeSpecial = parts[1] || "";
      }
    }

    enabled: root.enabled
    target: Hyprland
  }
}
