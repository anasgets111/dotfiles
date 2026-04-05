pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
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
  readonly property var _layoutState: {
    normalizedWorkspaces;
    return enabled ? WorkspaceService.buildLayout(normalizedWorkspaces, "", []) : _emptyLayout;
  }
  readonly property bool enabled: MainService.ready && MainService.currentWM === "niri"
  readonly property int currentWorkspace: focusedWorkspace?.id ?? trackedWorkspaceId
  readonly property int currentWorkspaceIndex: focusedWorkspace?.idx ?? -1
  readonly property string focusedOutput: _layoutState.focusedOutput
  readonly property var focusedWorkspace: _layoutState.focusedWorkspace
  readonly property list<int> groupBoundaries: _layoutState.groupBoundaries
  property var normalizedWorkspaces: []
  readonly property list<string> outputsOrder: _layoutState.outputsOrder
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
  property int trackedWorkspaceId: 1
  property var windowsById: ({})
  readonly property var workspaces: _layoutState.workspaces
  property var workspacesById: ({})

  function focusWorkspaceById(workspaceId: int): void {
    if (!enabled)
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
    const workspace = workspaces.find(ws => ws?.idx === workspaceIndex);
    workspace ? focusWorkspaceById(workspace.id) : console.warn(`[Niri] Invalid index: ${workspaceIndex}`);
  }

  function focusWorkspace(ws: var): void {
    if (!enabled || !ws)
      return;
    focusWorkspaceById(ws.id);
  }

  function handleEvent(line: string): void {
    if (!line)
      return;

    try {
      const event = JSON.parse(line);

      if (event.WorkspacesChanged) {
        const updatedWorkspaces = {};
        event.WorkspacesChanged.workspaces.forEach(ws => updatedWorkspaces[ws.id] = ws);
        workspacesById = updatedWorkspaces;

        const focusedWorkspace = event.WorkspacesChanged.workspaces.find(ws => ws.is_focused);
        if (focusedWorkspace && focusedWorkspace.id !== trackedWorkspaceId) {
          trackedWorkspaceId = focusedWorkspace.id;
        } else {
          Qt.callLater(rebuildWorkspaceList);
        }
      } else if (event.WorkspaceActivated) {
        trackedWorkspaceId = event.WorkspaceActivated.id;
      } else if (event.WindowsChanged) {
        const updatedWindows = {};
        event.WindowsChanged.windows.forEach(win => updatedWindows[win.id] = win);
        windowsById = updatedWindows;
        Qt.callLater(rebuildWorkspaceList);
      } else if (event.WindowOpenedOrChanged) {
        const window = event.WindowOpenedOrChanged.window;
        windowsById[window.id] = window;
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
    const allWorkspaces = [];
    const populatedIds = new Set(Object.values(windowsById).filter(win => win.workspace_id !== null).map(win => String(win.workspace_id)));

    for (const workspaceId in workspacesById) {
      const rawWorkspace = workspacesById[workspaceId];
      const isCurrentlyFocused = rawWorkspace.id === trackedWorkspaceId;

      allWorkspaces.push({
        id: rawWorkspace.id,
        idx: rawWorkspace.idx,
        focused: isCurrentlyFocused,
        populated: populatedIds.has(String(rawWorkspace.id)),
        output: rawWorkspace.output ?? "",
        name: rawWorkspace.name ?? ""
      });
    }

    normalizedWorkspaces = allWorkspaces;
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
    if (enabled && requestSocket.connected) {
      requestSocket.write(JSON.stringify(request) + "\n");
    }
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
  onTrackedWorkspaceIdChanged:
    Qt.callLater(rebuildWorkspaceList);

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
