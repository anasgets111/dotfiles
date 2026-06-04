pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Services
import qs.Services.WM

Singleton {
  id: root

  readonly property var _emptyLayout: ({
      focusedOutput: "",
      focusedWorkspace: null,
      groupBoundaries: [],
      outputsOrder: [],
      workspaces: []
    })
  readonly property var _layoutState: enabled ? WorkspaceService.buildLayout(normalizedWorkspaces, "", []) : _emptyLayout
  readonly property int currentWorkspace: focusedWorkspace?.id ?? trackedWorkspaceId
  readonly property int currentWorkspaceIndex: focusedWorkspace?.idx ?? -1
  readonly property bool enabled: MainService.ready && MainService.currentWM === "niri"
  readonly property string focusedOutput: _layoutState.focusedOutput
  readonly property var focusedWorkspace: _layoutState.focusedWorkspace
  readonly property bool fullscreenVisible: enabled && visibleWindowKeys.size > 0 && ToplevelManager.toplevels.values.some(toplevel => toplevel.fullscreen && visibleWindowKeys.has(root._windowKey(toplevel.appId, toplevel.title)))
  readonly property list<int> groupBoundaries: _layoutState.groupBoundaries
  property var normalizedWorkspaces: []
  readonly property list<string> outputsOrder: _layoutState.outputsOrder
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
  property int trackedWorkspaceId: 1
  property var visibleWindowKeys: new Set()
  property var windowsById: ({})
  readonly property var workspaces: _layoutState.workspaces
  property var workspacesById: ({})

  function _activateWorkspace(workspaceId: int): void {
    const activated = workspacesById[workspaceId];
    if (activated)
      for (const workspace of Object.values(workspacesById))
        if (workspace.output === activated.output)
          workspace.is_active = workspace.id === workspaceId;
    trackedWorkspaceId = workspaceId;
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

    const focusedWorkspace = sourceWorkspaces.find(workspace => workspace.is_focused);
    if (focusedWorkspace && focusedWorkspace.id !== trackedWorkspaceId)
      trackedWorkspaceId = focusedWorkspace.id;
    else
      Qt.callLater(rebuildWorkspaceList);
  }

  function _windowKey(appId: string, title: string): string {
    return JSON.stringify([appId ?? "", title ?? ""]);
  }

  function focusWorkspace(workspace: var): void {
    focusWorkspaceById(workspace?.id ?? -1);
  }

  function focusWorkspaceById(workspaceId: int): void {
    if (!enabled || workspaceId <= 0)
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
    if (!enabled)
      return;
    const workspace = workspaces.find(candidate => candidate?.idx === workspaceIndex);
    if (!workspace) {
      console.warn(`[Niri] Invalid index: ${workspaceIndex}`);
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
        _activateWorkspace(event.WorkspaceActivated.id);
      } else if (event.WindowsChanged) {
        windowsById = _indexById(event.WindowsChanged.windows);
        Qt.callLater(rebuildWorkspaceList);
      } else if (event.WindowOpenedOrChanged) {
        const changedWindow = event.WindowOpenedOrChanged.window;
        windowsById[changedWindow.id] = changedWindow;
        Qt.callLater(rebuildWorkspaceList);
      } else if (event.WindowClosed) {
        delete windowsById[event.WindowClosed.id];
        Qt.callLater(rebuildWorkspaceList);
      }
    } catch (error) {
      console.warn(`[Niri] Parse error: ${error}`);
    }
  }

  function rebuildWorkspaceList(): void {
    const populatedWorkspaceIds = new Set(Object.values(windowsById).filter(window => window.workspace_id !== null && window.workspace_id !== undefined).map(window => window.workspace_id));

    normalizedWorkspaces = Object.values(workspacesById).map(rawWorkspace => ({
          id: rawWorkspace.id,
          idx: rawWorkspace.idx,
          focused: rawWorkspace.id === trackedWorkspaceId,
          populated: populatedWorkspaceIds.has(rawWorkspace.id),
          output: rawWorkspace.output ?? "",
          name: rawWorkspace.name ?? ""
        }));

    const activeWorkspaceIds = new Set(Object.values(workspacesById).filter(workspace => workspace.is_active).map(workspace => workspace.id));
    visibleWindowKeys = new Set(Object.values(windowsById).filter(window => activeWorkspaceIds.has(window.workspace_id)).map(window => _windowKey(window.app_id, window.title)));
  }

  function refresh(): void {
    if (!enabled || !socketPath)
      return;
    eventStreamSocket.connected = false;
    eventStreamSocket.connected = true;
    requestSocket.connected = false;
    requestSocket.connected = true;
  }

  function sendAction(request: var): void {
    if (enabled && requestSocket.connected)
      requestSocket.write(JSON.stringify(request) + "\n");
  }

  Component.onCompleted: {
    if (enabled)
      startupTimer.start();
  }
  onEnabledChanged: {
    eventStreamSocket.connected = enabled && !!socketPath;
    requestSocket.connected = enabled && !!socketPath;
    if (enabled)
      startupTimer.restart();
  }
  onTrackedWorkspaceIdChanged: Qt.callLater(rebuildWorkspaceList)

  Socket {
    id: eventStreamSocket

    path: root.socketPath

    parser: SplitParser {
      splitMarker: "\n"

      onRead: line => root.handleEvent(line)
    }

    onConnectionStateChanged: {
      if (connected)
        write('"EventStream"\n');
    }
  }

  Socket {
    id: requestSocket

    path: root.socketPath
  }

  Timer {
    id: startupTimer

    interval: 200

    onTriggered: root.refresh()
  }
}
