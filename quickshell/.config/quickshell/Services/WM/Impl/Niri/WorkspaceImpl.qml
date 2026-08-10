pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.WM.Impl.Niri

Singleton {
  id: root

  readonly property var _populatedWorkspaceIds: new Set(NiriService.windows.filter(window => window.workspace_id !== null && window.workspace_id !== undefined).map(window => window.workspace_id))
  readonly property bool fullscreenVisible: visibleWindowKeys.size > 0 && ToplevelManager.toplevels.values.some(toplevel => toplevel.fullscreen && visibleWindowKeys.has(root._windowKey(toplevel.appId, toplevel.title)))
  readonly property bool hasOverview: true
  readonly property var visibleWindowKeys: {
    const activeWorkspaceIds = new Set(NiriService.workspaces.filter(workspace => workspace.is_active).map(workspace => workspace.id));
    return new Set(NiriService.windows.filter(window => activeWorkspaceIds.has(window.workspace_id)).map(window => _windowKey(window.app_id, window.title)));
  }
  // ponytail: keep opaque u64 IDs out of QML int; switch to strings beyond JSON's 53-bit ceiling.
  readonly property var workspaces: NiriService.workspaces.map(workspace => ({
        id: workspace.id,
        idx: workspace.idx,
        focused: workspace.is_focused,
        populated: _populatedWorkspaceIds.has(workspace.id),
        appId: _workspaceAppIdFrom(NiriService.windows.filter(window => window.workspace_id === workspace.id)),
        output: workspace.output ?? ""
      }))

  function _selfCheck(): bool {
    const focusedApp = _workspaceAppIdFrom([
      {app_id: "first", is_focused: false},
      {app_id: "focused", is_focused: true}
    ]);
    return focusedApp === "focused" && _workspaceAppIdFrom([{app_id: "first"}]) === "first";
  }
  function _workspaceAppIdFrom(windows: var): string {
    return String(windows.find(window => window.is_focused)?.app_id ?? windows[0]?.app_id ?? "");
  }
  // ponytail: appId/title can collide because Niri IPC and foreign-toplevel share no stable ID.
  function _windowKey(appId: string, title: string): string {
    return JSON.stringify([appId ?? "", title ?? ""]);
  }
  function focusWorkspace(workspace: var): void {
    const workspaceId = workspace?.id;
    if (workspaceId === null || workspaceId === undefined)
      return;
    NiriService.request({
      Action: {
        FocusWorkspace: {
          reference: {
            Id: workspaceId
          }
        }
      }
    }, null);
  }

  Component.onCompleted: console.assert(_selfCheck(), "Niri workspace app selection self-check failed")
}
