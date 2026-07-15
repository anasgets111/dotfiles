pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.Utils
import qs.Services.WM

Singleton {
  id: root

  readonly property var _layoutState: WorkspaceArrangement.buildLayout(normalizedWorkspaces, "", [])
  readonly property int currentWorkspaceIndex: focusedWorkspace?.idx ?? -1
  readonly property string focusedOutput: _layoutState.focusedOutput
  readonly property var focusedWorkspace: _layoutState.focusedWorkspace
  // ponytail: Niri IPC IDs are not exposed by foreign-toplevel handles, so
  // appId/title matching can conservatively collide. Replace this bridge when
  // either API exposes a shared stable window identity.
  readonly property bool fullscreenVisible: visibleWindowKeys.size > 0 && ToplevelManager.toplevels.values.some(toplevel => toplevel.fullscreen && visibleWindowKeys.has(root._windowKey(toplevel.appId, toplevel.title)))
  readonly property bool hasOverview: true
  property var normalizedWorkspaces: []
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
  // ponytail: keep opaque u64 IDs out of QML int; JSON numbers still have a
  // 53-bit ceiling. Switch identity keys to strings if Niri exposes them so.
  property var trackedWorkspaceId: null
  property var visibleWindowKeys: new Set()
  property var windows: []
  readonly property var workspaces: _layoutState.workspaces
  property var workspacesById: ({})

  function _activateWorkspace(activation: var): void {
    const workspaceId = activation?.id;
    if (workspaceId === null || workspaceId === undefined)
      return;
    const activated = workspacesById[workspaceId];
    if (activated)
      for (const workspace of Object.values(workspacesById))
        if (workspace.output === activated.output)
          workspace.is_active = workspace.id === workspaceId;
    if (activation?.focused === true && trackedWorkspaceId !== workspaceId)
      trackedWorkspaceId = workspaceId;
    else
      Qt.callLater(rebuildWorkspaceList);
  }
  function _indexById(items: var): var {
    const indexedItems = {};
    for (const item of Array.isArray(items) ? items : [])
      indexedItems[item.id] = item;
    return indexedItems;
  }
  function _updateWorkspaces(rawWorkspaces: var): void {
    const sourceWorkspaces = Array.isArray(rawWorkspaces) ? rawWorkspaces : [];
    workspacesById = _indexById(sourceWorkspaces);

    const focusedWorkspaceId = sourceWorkspaces.find(workspace => workspace.is_focused)?.id ?? null;
    if (focusedWorkspaceId !== trackedWorkspaceId)
      trackedWorkspaceId = focusedWorkspaceId;
    else
      Qt.callLater(rebuildWorkspaceList);
  }
  function _windowKey(appId: string, title: string): string {
    return JSON.stringify([appId ?? "", title ?? ""]);
  }
  function focusWorkspace(workspace: var): void {
    focusWorkspaceById(workspace?.id ?? null);
  }
  function focusWorkspaceById(workspaceId: var): void {
    if (workspaceId === null || workspaceId === undefined)
      return;
    sendAction({
      Action: {
        FocusWorkspace: {
          reference: {
            Id: workspaceId
          }
        }
      }
    });
  }
  function focusWorkspaceByIndex(workspaceIndex: int): void {
    const workspace = workspaces.find(candidate => candidate?.idx === workspaceIndex);
    if (!workspace) {
      Logger.warn("WorkspaceImpl(Niri)", `Invalid index: ${workspaceIndex}`);
      return;
    }
    focusWorkspaceById(workspace.id);
  }
  function handleEvent(line: string): void {
    if (!line)
      return;

    try {
      const event = JSON.parse(line);

      if (event.WorkspacesChanged) {
        _updateWorkspaces(event.WorkspacesChanged.workspaces);
      } else if (event.WorkspaceActivated) {
        _activateWorkspace(event.WorkspaceActivated);
      } else if (event.WindowsChanged) {
        windows = Array.isArray(event.WindowsChanged.windows) ? event.WindowsChanged.windows : [];
        Qt.callLater(rebuildWorkspaceList);
      } else if (event.WindowOpenedOrChanged) {
        const changedWindow = event.WindowOpenedOrChanged.window;
        const windowIndex = windows.findIndex(window => window.id === changedWindow.id);
        windows = windowIndex < 0 ? [...windows, changedWindow] : windows.map((window, index) => index === windowIndex ? changedWindow : window);
        Qt.callLater(rebuildWorkspaceList);
      } else if (event.WindowClosed) {
        windows = windows.filter(window => window.id !== event.WindowClosed.id);
        Qt.callLater(rebuildWorkspaceList);
      }
    } catch (error) {
      Logger.warn("WorkspaceImpl(Niri)", `Parse error: ${error}`);
    }
  }
  function rebuildWorkspaceList(): void {
    const populatedWorkspaceIds = new Set(windows.filter(window => window.workspace_id !== null && window.workspace_id !== undefined).map(window => window.workspace_id));

    normalizedWorkspaces = Object.values(workspacesById).map(rawWorkspace => ({
          id: rawWorkspace.id,
          idx: rawWorkspace.idx,
          focused: rawWorkspace.id === trackedWorkspaceId,
          populated: populatedWorkspaceIds.has(rawWorkspace.id),
          output: rawWorkspace.output ?? "",
          name: rawWorkspace.name ?? ""
        }));

    const activeWorkspaceIds = new Set(Object.values(workspacesById).filter(workspace => workspace.is_active).map(workspace => workspace.id));
    visibleWindowKeys = new Set(windows.filter(window => activeWorkspaceIds.has(window.workspace_id)).map(window => _windowKey(window.app_id, window.title)));
  }
  function sendAction(request: var): void {
    if (requestSocket.connected) {
      requestSocket.write(JSON.stringify(request) + "\n");
      requestSocket.flush();
    }
  }

  onTrackedWorkspaceIdChanged: Qt.callLater(rebuildWorkspaceList)

  NiriSocket {
    eventStream: true
    path: root.socketPath

    onLineRead: line => root.handleEvent(line)
  }
  NiriSocket {
    id: requestSocket

    path: root.socketPath
  }
}
