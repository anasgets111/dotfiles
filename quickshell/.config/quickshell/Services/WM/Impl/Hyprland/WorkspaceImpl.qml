pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Services

Singleton {
  id: root

  property string _activeSpecialName: ""
  readonly property var _layoutState: {
    if (!enabled)
      return {
        ws: [],
        special: [],
        out: [],
        bounds: []
      };

    const rawWs = Array.from(Hyprland.workspaces.values);
    const rawMons = Array.from(Hyprland.monitors.values);
    const focusedName = focusedOutput;

    const outOrder = rawMons.sort((a, b) => {
      const aName = a?.name ?? "";
      const bName = b?.name ?? "";
      return aName === focusedName ? -1 : bName === focusedName ? 1 : aName.localeCompare(bName);
    }).map(m => m?.name ?? "");

    const regular = [];
    const special = [];
    const counts = new Map();

    for (const w of rawWs) {
      if (w.id < 0) {
        special.push({
          name: w.name ?? `special:${w.id}`
        });
        continue;
      }

      const outName = w.monitor?.name ?? "";
      const winCount = w.toplevels?.length ?? w.lastIpcObject?.windows ?? 0;

      regular.push({
        id: w.id,
        idx: w.id,
        focused: w.focused,
        populated: winCount > 0,
        output: outName
      });

      counts.set(outName, (counts.get(outName) ?? 0) + 1);
    }

    regular.sort((a, b) => a.id - b.id);

    const bounds = [];
    let acc = 0;
    for (const out of outOrder) {
      acc += counts.get(out) ?? 0;
      if (acc > 0 && acc < regular.length) {
        bounds.push(acc);
      }
    }

    return {
      ws: regular,
      special: special,
      out: outOrder,
      bounds: bounds
    };
  }
  property int _previousWorkspaceId: 1
  property int _trackerWorkspaceId: 1
  readonly property string activeSpecial: _activeSpecialName
  readonly property int currentWorkspace: Hyprland.focusedWorkspace?.id ?? 1
  readonly property int currentWorkspaceId: currentWorkspace
  property bool enabled: MainService.ready && MainService.currentWM === "hyprland"
  readonly property string focusedOutput: Hyprland.focusedMonitor?.name ?? ""
  readonly property var groupBoundaries: _layoutState.bounds
  readonly property var outputsOrder: _layoutState.out
  readonly property int previousWorkspace: _previousWorkspaceId
  readonly property var specialWorkspaces: _layoutState.special
  readonly property var workspaces: _layoutState.ws

  function focusWorkspaceByIndex(idx: int): void {
    if (enabled && idx > 0)
      Hyprland.dispatch(`workspace ${idx}`);
  }

  function toggleSpecial(name: string): void {
    if (enabled && name)
      Hyprland.dispatch(`togglespecialworkspace ${name}`);
  }

  Component.onCompleted: {
    if (enabled)
      _trackerWorkspaceId = currentWorkspace;
  }
  onCurrentWorkspaceChanged: {
    if (currentWorkspace !== _trackerWorkspaceId) {
      _previousWorkspaceId = _trackerWorkspaceId;
      _trackerWorkspaceId = currentWorkspace;
    }
  }

  Connections {
    function onRawEvent(event: HyprlandEvent): void {
      if (event.name === "activespecial") {
        const workspaceName = event.data ? event.data.split(",")[0] : "";
        root._activeSpecialName = workspaceName;
      }
    }

    enabled: root.enabled
    target: Hyprland
  }
}
