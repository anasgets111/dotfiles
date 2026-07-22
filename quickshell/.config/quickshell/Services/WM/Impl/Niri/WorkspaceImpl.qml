pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.WM.Impl.Niri

Singleton {
  id: root

  // ponytail: appId/title can collide because Niri IPC and foreign-toplevel share no stable ID.
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
        output: workspace.output ?? ""
      }))

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
}
