pragma Singleton
import QtQuick
import Quickshell
import qs.Services
import qs.Services.WM
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: root

  readonly property string activeSpecial: backend?.activeSpecial ?? ""
  readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.WorkspaceImpl : MainService.currentWM === "niri" ? Niri.WorkspaceImpl : null
  readonly property int currentWorkspace: backend?.currentWorkspace ?? -1
  readonly property int currentWorkspaceIndex: backend?.currentWorkspaceIndex ?? -1
  readonly property var displayWorkspaces: WorkspaceArrangement.buildDisplayWorkspaces(workspaces, currentWorkspaceIndex, backend?.fillsEmptyWorkspaceSlots ?? false, 10)
  readonly property string focusedOutput: backend?.focusedOutput ?? ""
  readonly property var focusedWorkspace: backend?.focusedWorkspace ?? null
  readonly property bool fullscreenVisible: backend?.fullscreenVisible ?? false
  readonly property var groupBoundaries: backend?.groupBoundaries ?? []
  readonly property bool hasOverview: backend?.hasOverview ?? false
  readonly property var outputsOrder: backend?.outputsOrder ?? []
  readonly property bool ready: backend !== null
  readonly property var specialWorkspaces: backend?.specialWorkspaces ?? []
  readonly property bool supportsSpecialWorkspaces: backend?.supportsSpecialWorkspaces ?? false
  readonly property var workspaces: backend?.workspaces ?? []

  function focusWorkspace(workspace: var): void {
    if (workspace)
      backend?.focusWorkspace(workspace);
  }

  function focusWorkspaceByIndex(workspaceIndex: int): void {
    backend?.focusWorkspaceByIndex(workspaceIndex);
  }

  function toggleSpecial(name: string): void {
    backend?.toggleSpecial(name);
  }
}
