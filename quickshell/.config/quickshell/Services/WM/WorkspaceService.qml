pragma Singleton
import QtQuick
import Quickshell
import qs.Services
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

/**
 * Unified workspace service facade.
 *
 * Workspace object structure (unified across WMs):
 *   {
 *     id: number,        // unique identifier (Hyprland: equals idx, Niri: unique per session)
 *     idx: number,       // visual index for display (1-based)
 *     focused: bool,     // globally focused workspace
 *     populated: bool,   // has windows
 *     output: string,    // monitor/output name
 *     name?: string      // optional workspace name (Niri only)
 *   }
 *
 * Special workspaces (Hyprland only):
 *   - Stored separately in specialWorkspaces array
 *   - Have negative IDs (e.g., -98, -99)
 *   - Toggled via toggleSpecial(name)
 */
Singleton {
  id: root

  readonly property string activeSpecial: backend?.activeSpecial ?? ""
  readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.WorkspaceImpl : MainService.currentWM === "niri" ? Niri.WorkspaceImpl : null
  readonly property int currentWorkspace: backend?.currentWorkspace ?? -1
  readonly property string focusedOutput: backend?.focusedOutput ?? ""
  readonly property var groupBoundaries: backend?.groupBoundaries ?? []
  readonly property var outputsOrder: backend?.outputsOrder ?? []
  readonly property int previousWorkspace: backend?.previousWorkspace ?? -1
  readonly property var specialWorkspaces: backend?.specialWorkspaces ?? []
  readonly property var workspaces: backend?.workspaces ?? []

  function focusWorkspaceByIndex(idx) {
    backend?.focusWorkspaceByIndex(idx);
  }

  function focusWorkspaceByWs(ws) {
    if (backend && typeof backend.focusWorkspaceByWs === "function") {
      backend.focusWorkspaceByWs(ws);
      return;
    }
    if (ws?.idx !== undefined) {
      backend?.focusWorkspaceByIndex(ws.idx);
    }
  }

  function refresh() {
    backend?.refresh();
  }

  function toggleSpecial(name) {
    backend?.toggleSpecial(name);
  }
}
