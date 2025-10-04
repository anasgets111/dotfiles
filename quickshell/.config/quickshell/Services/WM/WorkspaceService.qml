pragma Singleton
import QtQuick
import Quickshell
import qs.Services
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: root

  readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.WorkspaceImpl : MainService.currentWM === "niri" ? Niri.WorkspaceImpl : null
  readonly property string activeSpecial: backend?.activeSpecial || ""
  readonly property int currentWorkspace: backend?.currentWorkspace || -1
  readonly property int currentWorkspaceId: backend?.currentWorkspaceId ?? -1
  readonly property string focusedOutput: backend?.focusedOutput || ""
  readonly property var groupBoundaries: backend?.groupBoundaries || []
  readonly property var outputsOrder: backend?.outputsOrder || []
  readonly property int previousWorkspace: backend?.previousWorkspace || -1
  readonly property var specialWorkspaces: backend?.specialWorkspaces || []
  readonly property var workspaces: backend?.workspaces || []

  function focusWorkspaceByIndex(idx) {
    backend?.focusWorkspaceByIndex(idx);
  }
  function refresh() {
    backend?.refresh();
  }
  function toggleSpecial(name) {
    backend?.toggleSpecial(name);
  }

  function focusWorkspaceByWs(wsObj) {
    if (!backend || !wsObj)
      return;
    backend.focusWorkspaceByWs ? backend.focusWorkspaceByWs(wsObj) : backend.focusWorkspaceByObject(wsObj);
  }

  Binding {
    target: Hypr.WorkspaceImpl
    property: "enabled"
    value: MainService.ready && root.backend === Hypr.WorkspaceImpl
  }
  Binding {
    target: Niri.WorkspaceImpl
    property: "enabled"
    value: MainService.ready && root.backend === Niri.WorkspaceImpl
  }
}
