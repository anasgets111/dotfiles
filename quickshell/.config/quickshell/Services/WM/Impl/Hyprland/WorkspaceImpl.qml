pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Services
import qs.Services.WM

Singleton {
  id: root

  readonly property var _emptyLayout: ({
      focusedOutput: "",
      focusedWorkspace: null,
      groupBoundaries: [],
      outputsOrder: [],
      specialWorkspaces: [],
      workspaces: []
    })
  readonly property var _layoutState: {
    _updateTick;
    return enabled ? _calcLayout() : _emptyLayout;
  }
  readonly property var _structuralEvents: ["workspace", "workspacev2", "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2", "focusedmon", "monitoradded", "monitoraddedv2", "monitorremoved", "moveworkspace", "openwindow", "closewindow", "movewindow", "movewindowv2"]
  property int _updateTick: 0
  property string activeSpecial: ""
  readonly property int currentWorkspace: focusedWorkspace?.id ?? -1
  readonly property int currentWorkspaceIndex: focusedWorkspace?.idx ?? -1
  readonly property bool enabled: MainService.currentWM === "hyprland"
  readonly property string focusedOutput: _layoutState.focusedOutput
  readonly property var focusedWorkspace: _layoutState.focusedWorkspace
  readonly property var groupBoundaries: _layoutState.groupBoundaries
  readonly property var outputsOrder: _layoutState.outputsOrder
  readonly property var specialWorkspaces: _layoutState.specialWorkspaces
  readonly property var workspaces: _layoutState.workspaces

  function _calcLayout(): var {
    const rawWs = Array.from(Hyprland.workspaces.values);
    const rawMons = Array.from(Hyprland.monitors.values);
    const outputOrderHint = rawMons.sort((a, b) => (b.focused - a.focused) || a.name.localeCompare(b.name)).map(m => m.name);

    const regular = [];
    const special = [];

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
      const winCount = w.lastIpcObject?.windows ?? Array.from(w.toplevels.values).length;

      regular.push({
        id: w.id,
        idx: w.id,
        focused: w.focused,
        populated: winCount > 0,
        output: outName,
        name: w.name ?? ""
      });
    }

    const layout = WorkspaceService.buildLayout(regular, Hyprland.focusedMonitor?.name ?? "", outputOrderHint);
    return {
      focusedOutput: layout.focusedOutput,
      focusedWorkspace: layout.focusedWorkspace,
      groupBoundaries: layout.groupBoundaries,
      outputsOrder: layout.outputsOrder,
      specialWorkspaces: special,
      workspaces: layout.workspaces
    };
  }

  function focusWorkspace(ws: var): void {
    if (enabled && (ws?.idx ?? 0) > 0)
      focusWorkspaceByIndex(ws.idx);
  }

  function focusWorkspaceByIndex(idx: int): void {
    if (enabled && idx > 0)
      Hyprland.dispatch(`workspace ${idx}`);
  }

  function refresh(): void {
    if (!enabled)
      return;
    Hyprland.refreshMonitors();
    Hyprland.refreshWorkspaces();
    _updateTick++;
  }

  function toggleSpecial(name: string): void {
    if (enabled && name)
      Hyprland.dispatch(`togglespecialworkspace ${name}`);
  }

  Component.onCompleted: {
    if (enabled) {
      refresh();
      Qt.callLater(refresh);
    }
  }
  onEnabledChanged: if (enabled) {
    refresh();
    Qt.callLater(refresh);
  }

  Connections {
    function onReloadCompleted() {
      root.refresh();
      Qt.callLater(root.refresh);
    }

    enabled: root.enabled
    target: Quickshell
  }

  Connections {
    function onRawEvent(event: var): void {
      if (event.name === "activespecialv2") {
        root.activeSpecial = event.data.split(",")[1] || "";
        root._updateTick++;
      } else if (root._structuralEvents.includes(event.name)) {
        root.refresh();
      }
    }

    enabled: root.enabled
    target: Hyprland
  }
}
