pragma Singleton
import QtQuick
import Quickshell
import qs.Services
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: root

  readonly property string activeSpecial: backend?.activeSpecial || ""
  readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.WorkspaceImpl : MainService.currentWM === "niri" ? Niri.WorkspaceImpl : null
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

  function focusWorkspaceByWs(wsObj) {
    (backend?.focusWorkspaceByWs || backend?.focusWorkspaceByObject)?.(wsObj);
  }

  function refresh() {
    backend?.refresh();
  }

  function toggleSpecial(name) {
    backend?.toggleSpecial(name);
  }

  Binding {
    property: "enabled"
    target: Hypr.WorkspaceImpl
    value: MainService.ready && root.backend === Hypr.WorkspaceImpl
  }

  Binding {
    property: "enabled"
    target: Niri.WorkspaceImpl
    value: MainService.ready && root.backend === Niri.WorkspaceImpl
  }
}
