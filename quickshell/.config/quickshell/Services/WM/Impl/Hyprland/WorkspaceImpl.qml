pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
  id: root

  property int _revision: 0
  readonly property var _state: _revision >= 0 ? _buildState() : null
  readonly property var _structuralEvents: ["workspace", "workspacev2", "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2", "focusedmon", "focusedmonv2", "fullscreen", "monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "moveworkspace", "moveworkspacev2", "activespecial", "activespecialv2", "configreloaded", "openwindow", "closewindow", "movewindow", "movewindowv2"]
  readonly property var _toplevelEvents: ["configreloaded", "openwindow", "closewindow", "movewindow", "movewindowv2"]
  readonly property bool fillsEmptyWorkspaceSlots: true
  readonly property string focusedOutput: Hyprland.focusedMonitor?.name ?? ""
  readonly property bool fullscreenVisible: _revision >= 0 && Array.from(Hyprland.workspaces.values).some(ws => ws.active && ws.hasFullscreen)
  readonly property var specialWorkspaces: _state.specialWorkspaces
  readonly property bool supportsSpecialWorkspaces: true
  readonly property var workspaces: _state.workspaces

  function _buildState(): var {
    const monitors = Array.from(Hyprland.monitors.values);
    const activeSpecialNames = new Set(monitors.map(monitor => String(monitor.lastIpcObject?.specialWorkspace?.name ?? "")).filter(Boolean));

    const regularWorkspaces = [];
    const specialWorkspaces = [];

    for (const rawWorkspace of Hyprland.workspaces.values) {
      if (rawWorkspace.id < -1) {
        specialWorkspaces.push({
          active: activeSpecialNames.has(rawWorkspace.name),
          name: rawWorkspace.name
        });
        continue;
      }

      if (rawWorkspace.id <= 0)
        continue;

      const outputName = rawWorkspace.monitor?.name ?? "";
      const toplevels = Array.from(rawWorkspace.toplevels.values);
      const windowCount = rawWorkspace.lastIpcObject?.windows ?? toplevels.length;

      regularWorkspaces.push({
        id: rawWorkspace.id,
        idx: rawWorkspace.id,
        focused: rawWorkspace.focused,
        populated: windowCount > 0,
        appId: _workspaceAppIdFrom(toplevels),
        output: outputName
      });
    }

    return {
      specialWorkspaces,
      workspaces: regularWorkspaces
    };
  }
  function focusWorkspace(workspace: var): void {
    if ((workspace?.idx ?? 0) > 0)
      focusWorkspaceByIndex(workspace.idx);
  }
  function _workspaceAppIdFrom(toplevels: var): string {
    const activeToplevel = toplevels.find(toplevel => toplevel.activated) ?? toplevels[0];
    return activeToplevel?.wayland?.appId ?? activeToplevel?.lastIpcObject?.class ?? "";
  }
  function _selfCheck(): bool {
    const focusedApp = _workspaceAppIdFrom([
      {wayland: {appId: "first"}, activated: false},
      {wayland: {appId: "focused"}, activated: true}
    ]);
    return focusedApp === "focused" && _workspaceAppIdFrom([{lastIpcObject: {class: "first"}}]) === "first";
  }
  function focusWorkspaceByIndex(workspaceIndex: int): void {
    if (workspaceIndex > 0)
      Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspaceIndex} })`);
  }
  function refresh(includeToplevels = true): void {
    Hyprland.refreshMonitors();
    if (includeToplevels)
      Hyprland.refreshToplevels();
    Hyprland.refreshWorkspaces();
    _revision++;
  }
  function toggleSpecial(name: string): void {
    if (name)
      Hyprland.dispatch(`hl.dsp.workspace.toggle_special(${JSON.stringify(name)})`);
  }

  Component.onCompleted: {
    console.assert(_selfCheck(), "Hyprland workspace app selection self-check failed");
    refresh();
    Qt.callLater(refresh);
  }

  Connections {
    function onReloadCompleted() {
      root.refresh();
      Qt.callLater(root.refresh);
    }

    target: Quickshell
  }
  Connections {
    function onRawEvent(event: var): void {
      if (root._structuralEvents.includes(event.name))
        root.refresh(root._toplevelEvents.includes(event.name));
    }

    target: Hyprland
  }
}
