pragma Singleton
import QtQml
import QtQuick
import Quickshell
import qs.Services
import qs.Services.Utils
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: ws

  readonly property var backend: (MainService.currentWM === "hyprland" ? Hypr.WorkspaceImpl : (MainService.currentWM === "niri" ? Niri.WorkspaceImpl : null))
  readonly property string activeSpecial: backend ? backend.activeSpecial : ""
  readonly property int currentWorkspace: backend ? backend.currentWorkspace : -1
  readonly property int currentWorkspaceId: (backend && backend.currentWorkspaceId !== undefined) ? backend.currentWorkspaceId : -1
  readonly property string focusedOutput: backend ? backend.focusedOutput : ""
  readonly property var groupBoundaries: backend ? backend.groupBoundaries : []
  readonly property var outputsOrder: backend ? backend.outputsOrder : []
  readonly property int previousWorkspace: backend ? backend.previousWorkspace : -1
  readonly property var specialWorkspaces: backend ? backend.specialWorkspaces : []
  readonly property var workspaces: backend ? backend.workspaces : []

  function focusWorkspaceByIndex(idx) {
    if (backend?.focusWorkspaceByIndex)
      backend.focusWorkspaceByIndex(idx);
  }
  function focusWorkspaceByWs(wsObj) {
    if (!backend || !wsObj)
      return;
    if (backend.focusWorkspaceByWs)
      backend.focusWorkspaceByWs(wsObj);
    else if (backend.focusWorkspaceByObject)
      backend.focusWorkspaceByObject(wsObj);
  }
  function refresh() {
    backend?.refresh();
  }
  function toggleSpecial(name) {
    backend?.toggleSpecial(name);
  }

  onActiveSpecialChanged: {
    if (!ws.backend)
      return;
    const sp = ws.activeSpecial || "";
    if (sp)
      Logger.log("Workspace", "special -> name='" + sp + "'");
    else
      Logger.log("Workspace", "special cleared");
  }
  onCurrentWorkspaceChanged: {
    if (!ws.backend)
      return;
    const idx = ws.currentWorkspace;
    if (idx > 0)
      Logger.log("Workspace", "focus -> output='" + (ws.focusedOutput || "") + "', idx=" + idx);
  }
  onFocusedOutputChanged: {
    if (!ws.backend)
      return;
    const idx = ws.currentWorkspace;
    if (idx > 0)
      Logger.log("Workspace", "focus -> output='" + (ws.focusedOutput || "") + "', idx=" + idx);
  }
  Binding {
    property: "enabled"
    target: Hypr.WorkspaceImpl
    value: MainService.ready && (ws.backend === Hypr.WorkspaceImpl)
  }
  Binding {
    property: "enabled"
    target: Niri.WorkspaceImpl
    value: MainService.ready && (ws.backend === Niri.WorkspaceImpl)
  }
}
