pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
  id: root

  readonly property int currentWorkspace: trackedWorkspaceId
  readonly property bool enabled: MainService.ready && MainService.currentWM === "niri"
  property var flatWorkspaceList: []
  readonly property string focusedOutput: focusedOutputName
  property string focusedOutputName: ""
  readonly property list<int> groupBoundaries: outputGroupBoundaries
  property int lastTrackedWorkspaceId: 1
  property list<int> outputGroupBoundaries: []
  property list<string> outputOrderList: []
  readonly property list<string> outputsOrder: outputOrderList
  readonly property int previousWorkspace: lastTrackedWorkspaceId
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
  property int trackedWorkspaceId: 1
  property var windowsById: ({})
  readonly property var workspaces: flatWorkspaceList
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
    const workspace = workspaces.find(ws => ws.idx === workspaceIndex);
    workspace ? focusWorkspaceById(workspace.id) : console.warn(`[Niri] Invalid index: ${workspaceIndex}`);
  }

  function focusWorkspaceByWs(ws: var): void {
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
    const workspacesByOutput = {};
    const allWorkspaces = [];
    const boundaries = [];
    const populatedIds = new Set(Object.values(windowsById).filter(win => win.workspace_id !== null).map(win => String(win.workspace_id)));
    let currentFocusedWorkspace = null;

    for (const workspaceId in workspacesById) {
      const rawWorkspace = workspacesById[workspaceId];
      const isCurrentlyFocused = rawWorkspace.id === trackedWorkspaceId;

      const workspace = {
        id: rawWorkspace.id,
        idx: rawWorkspace.idx,
        focused: isCurrentlyFocused,
        populated: populatedIds.has(String(rawWorkspace.id)),
        output: rawWorkspace.output ?? "",
        name: rawWorkspace.name ?? null
      };

      const outputName = workspace.output;
      if (!workspacesByOutput[outputName]) {
        workspacesByOutput[outputName] = [];
      }
      workspacesByOutput[outputName].push(workspace);

      if (isCurrentlyFocused) {
        currentFocusedWorkspace = workspace;
      }
    }

    if (currentFocusedWorkspace) {
      focusedOutputName = currentFocusedWorkspace.output;
    }

    outputOrderList = Object.keys(workspacesByOutput).sort((a, b) => {
      if (a === focusedOutputName)
        return -1;
      if (b === focusedOutputName)
        return 1;
      return a.localeCompare(b);
    });

    const totalWorkspaces = Object.keys(workspacesById).length;
    for (const outputName of outputOrderList) {
      const sortedWorkspaces = workspacesByOutput[outputName].sort((a, b) => a.idx - b.idx);
      allWorkspaces.push(...sortedWorkspaces);

      if (allWorkspaces.length < totalWorkspaces) {
        boundaries.push(allWorkspaces.length);
      }
    }

    flatWorkspaceList = allWorkspaces;
    outputGroupBoundaries = boundaries;
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
  onTrackedWorkspaceIdChanged: {
    if (trackedWorkspaceId !== lastTrackedWorkspaceId) {
      lastTrackedWorkspaceId = trackedWorkspaceId;
    }
    Qt.callLater(rebuildWorkspaceList);
  }

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