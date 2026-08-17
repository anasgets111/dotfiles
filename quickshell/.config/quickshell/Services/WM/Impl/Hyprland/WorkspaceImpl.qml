pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
  id: root

  readonly property bool fillsEmptyWorkspaceSlots: true
  readonly property string focusedOutput: Hyprland.focusedMonitor?.name ?? ""
  readonly property var fullscreenPopupContentTypes: new Map(Array.from(Hyprland.workspaces.values).filter(workspace => workspace.active && workspace.hasFullscreen).map(workspace => [workspace.monitor?.name ?? "", _fullscreenContentType(workspace)]).filter(entry => entry[0]))
  readonly property bool fullscreenVisible: fullscreenPopupContentTypes.size > 0
  readonly property var specialWorkspaces: {
    const activeSpecials = new Set(Array.from(Hyprland.monitors.values).map(monitor => monitor.lastIpcObject?.specialWorkspace?.name).filter(Boolean));
    return Array.from(Hyprland.workspaces.values).filter(workspace => (Number(workspace.name) || workspace.id) <= 0).map(workspace => ({
          name: workspace.name,
          active: activeSpecials.has(workspace.name)
        }));
  }
  readonly property bool supportsSpecialWorkspaces: true
  readonly property var workspaces: Array.from(Hyprland.workspaces.values).filter(workspace => (Number(workspace.name) || workspace.id) > 0).map(workspace => {
    const id = Number(workspace.name) || workspace.id;
    const windowCount = workspace.lastIpcObject?.windows ?? workspace.toplevels?.values?.length ?? 0;
    return {
      id,
      idx: id,
      focused: workspace.focused,
      populated: windowCount > 0,
      appId: _workspaceAppId(workspace),
      output: workspace.monitor?.name ?? ""
    };
  })

  function _fullscreenContentType(workspace: var): string {
    const toplevels = Array.from(workspace?.toplevels?.values ?? []);
    return toplevels.find(toplevel => (toplevel.lastIpcObject?.fullscreen ?? 0) > 0)?.lastIpcObject?.contentType ?? "";
  }
  function _selfCheck(): bool {
    const mock = {
      toplevels: {
        values: [
          {
            wayland: {
              appId: "first"
            },
            activated: false
          },
          {
            wayland: {
              appId: "focused"
            },
            activated: true
          }
        ]
      }
    };
    return _workspaceAppId(mock) === "focused";
  }
  function _workspaceAppId(workspace: var): string {
    const toplevels = Array.from(workspace?.toplevels?.values ?? []);
    const activeToplevel = toplevels.find(toplevel => toplevel.activated) ?? toplevels[0];
    return activeToplevel?.wayland?.appId ?? activeToplevel?.lastIpcObject?.class ?? "";
  }
  function focusWorkspace(workspace: var): void {
    focusWorkspaceByIndex(workspace?.idx ?? 0);
  }
  function focusWorkspaceByIndex(workspaceIndex: int): void {
    if (workspaceIndex > 0)
      Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspaceIndex} })`);
  }
  function refresh(): void {
    Hyprland.refreshMonitors();
    Hyprland.refreshToplevels();
    Hyprland.refreshWorkspaces();
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
    }

    target: Quickshell
  }
  Connections {
    function onRawEvent() {
      root.refresh();
    }

    target: Hyprland
  }
}
