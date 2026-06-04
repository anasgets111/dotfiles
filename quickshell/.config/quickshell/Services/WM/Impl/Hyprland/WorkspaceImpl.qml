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
    return enabled && _revision >= 0 ? _buildLayoutState() : _emptyLayout;
  }
  property int _revision: 0
  readonly property var _structuralEvents: ["workspace", "workspacev2", "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2", "focusedmon", "fullscreen", "monitoradded", "monitoraddedv2", "monitorremoved", "moveworkspace", "openwindow", "closewindow", "movewindow", "movewindowv2"]
  property string activeSpecial: ""
  readonly property int currentWorkspace: focusedWorkspace?.id ?? -1
  readonly property int currentWorkspaceIndex: focusedWorkspace?.idx ?? -1
  readonly property bool enabled: MainService.currentWM === "hyprland"
  readonly property string focusedOutput: _layoutState.focusedOutput
  readonly property var focusedWorkspace: _layoutState.focusedWorkspace
  readonly property bool fullscreenVisible: enabled && _revision >= 0 && Array.from(Hyprland.workspaces.values).some(ws => ws.active && ws.hasFullscreen)
  readonly property var groupBoundaries: _layoutState.groupBoundaries
  readonly property var outputsOrder: _layoutState.outputsOrder
  readonly property var specialWorkspaces: _layoutState.specialWorkspaces
  readonly property var workspaces: _layoutState.workspaces

  function _buildLayoutState(): var {
    const outputOrderHint = Array.from(Hyprland.monitors.values).sort((leftMonitor, rightMonitor) => (rightMonitor.focused - leftMonitor.focused) || leftMonitor.name.localeCompare(rightMonitor.name)).map(monitor => monitor.name);

    const regularWorkspaces = [];
    const specialWorkspaces = [];

    for (const rawWorkspace of Hyprland.workspaces.values) {
      if (rawWorkspace.id < -1) {
        specialWorkspaces.push({
          name: rawWorkspace.name
        });
        continue;
      }

      if (rawWorkspace.id <= 0)
        continue;

      const outputName = rawWorkspace.monitor?.name ?? "";
      const windowCount = rawWorkspace.lastIpcObject?.windows ?? Array.from(rawWorkspace.toplevels.values).length;

      regularWorkspaces.push({
        id: rawWorkspace.id,
        idx: rawWorkspace.id,
        focused: rawWorkspace.focused,
        populated: windowCount > 0,
        output: outputName,
        name: rawWorkspace.name ?? ""
      });
    }

    const layout = WorkspaceService.buildLayout(regularWorkspaces, Hyprland.focusedMonitor?.name ?? "", outputOrderHint);
    return {
      focusedOutput: layout.focusedOutput,
      focusedWorkspace: layout.focusedWorkspace,
      groupBoundaries: layout.groupBoundaries,
      outputsOrder: layout.outputsOrder,
      specialWorkspaces,
      workspaces: layout.workspaces
    };
  }

  function focusWorkspace(workspace: var): void {
    if (enabled && (workspace?.idx ?? 0) > 0)
      focusWorkspaceByIndex(workspace.idx);
  }

  function focusWorkspaceByIndex(workspaceIndex: int): void {
    if (enabled && workspaceIndex > 0)
      Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspaceIndex} })`);
  }

  function refresh(): void {
    if (!enabled)
      return;
    Hyprland.refreshMonitors();
    Hyprland.refreshWorkspaces();
    _revision++;
  }

  function toggleSpecial(name: string): void {
    if (enabled && name)
      Hyprland.dispatch(`hl.dsp.workspace.toggle_special(${JSON.stringify(name)})`);
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
        root._revision++;
      } else if (root._structuralEvents.includes(event.name)) {
        root.refresh();
      }
    }

    enabled: root.enabled
    target: Hyprland
  }
}
