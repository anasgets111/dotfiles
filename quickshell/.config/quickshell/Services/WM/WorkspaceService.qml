pragma Singleton
import QtQuick
import Quickshell
import qs.Services
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: root

  readonly property string activeSpecial: backend?.activeSpecial ?? ""
  readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.WorkspaceImpl : MainService.currentWM === "niri" ? Niri.WorkspaceImpl : null
  readonly property int currentWorkspace: backend?.currentWorkspace ?? -1
  readonly property int currentWorkspaceIndex: backend?.currentWorkspaceIndex ?? -1
  readonly property var displayWorkspaces: WorkspaceData.buildDisplayWorkspaces(workspaces, currentWorkspaceIndex, MainService.currentWM === "hyprland")
  readonly property string focusedOutput: backend?.focusedOutput ?? ""
  readonly property var focusedWorkspace: backend?.focusedWorkspace ?? null
  readonly property var groupBoundaries: backend?.groupBoundaries ?? []
  readonly property var outputsOrder: backend?.outputsOrder ?? []
  readonly property var specialWorkspaces: backend?.specialWorkspaces ?? []
  readonly property var workspaces: backend?.workspaces ?? []

  function focusWorkspace(ws) {
    if (ws)
      backend?.focusWorkspace(ws);
  }

  function focusWorkspaceByIndex(idx) {
    backend?.focusWorkspaceByIndex(idx);
  }

  function toggleSpecial(name) {
    backend?.toggleSpecial(name);
  }
}
