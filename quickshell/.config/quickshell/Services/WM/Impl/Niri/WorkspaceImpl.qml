pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.Utils

Singleton {
  id: root

  property int _previousWorkspaceId: 1
  property int _trackerWorkspaceId: 1
  readonly property string activeSpecial: ""
  property int currentWorkspace: 1
  property int currentWorkspaceId: -1
  property bool enabled: MainService.ready && MainService.currentWM === "niri"
  property string focusedOutput: ""
  property var groupBoundaries: []
  property var outputsOrder: []
  readonly property int previousWorkspace: _previousWorkspaceId
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
  readonly property var specialWorkspaces: []
  property var workspaces: []

  function focusWorkspaceById(id) {
    if (!enabled)
      return;
    send({
      Action: {
        FocusWorkspace: {
          reference: {
            Id: id
          }
        }
      }
    });
  }

  function focusWorkspaceByIndex(idx) {
    if (!enabled)
      return;
    const ws = workspaces.find(w => w.idx === idx);
    if (ws)
      focusWorkspaceById(ws.id);
  }

  function refresh() {
    if (!enabled || !socketPath)
      return;
    eventStreamSocket.connected = false;
    eventStreamSocket.connected = true;
    requestSocket.connected = false;
    requestSocket.connected = true;
  }

  function send(request) {
    if (enabled && requestSocket.connected)
      requestSocket.write(JSON.stringify(request) + "\n");
  }

  function toUnifiedWs(w) {
    return {
      id: w.id,
      idx: w.idx,
      focused: w.is_focused,
      populated: w.active_window_id !== null,
      output: w.output ?? "",
      name: w.name ?? null
    };
  }

  function toggleSpecial(name) {
  }

  function updateSingleFocus(id) {
    const ws = workspaces.find(w => w.id === id);
    if (!ws)
      return;

    if (root.currentWorkspace !== ws.idx) {
      root.currentWorkspace = ws.idx;
    }
    root.currentWorkspaceId = ws.id;
    root.focusedOutput = ws.output ?? root.focusedOutput;

    for (let i = 0; i < workspaces.length; i++) {
      workspaces[i].focused = (workspaces[i].id === id);
    }
    root.workspacesChanged();
  }

  function updateWorkspaces(arr) {
    const perOutput = Object.create(null);
    let focusedWs = null;

    for (const w of arr) {
      const ws = toUnifiedWs(w);
      const out = ws.output ?? "";
      if (!perOutput[out])
        perOutput[out] = [];
      perOutput[out].push(ws);
      if (ws.focused)
        focusedWs = ws;
    }

    if (focusedWs)
      root.focusedOutput = focusedWs.output;

    const order = Object.keys(perOutput).sort((a, b) => {
      if (a === focusedOutput)
        return -1;
      if (b === focusedOutput)
        return 1;
      return a.localeCompare(b);
    });
    root.outputsOrder = order;

    const flat = [];
    const bounds = [];
    const total = arr.length;
    for (const out of order) {
      const wsList = perOutput[out].sort((a, b) => a.idx - b.idx);
      flat.push(...wsList);
      if (flat.length < total)
        bounds.push(flat.length);
    }
    root.workspaces = flat;
    root.groupBoundaries = bounds;

    if (focusedWs) {
      if (root.currentWorkspace !== focusedWs.idx)
        root.currentWorkspace = focusedWs.idx;
      root.currentWorkspaceId = focusedWs.id;
    }
  }

  Component.onCompleted: if (enabled)
    _startupKick.start()
  onCurrentWorkspaceChanged: {
    if (currentWorkspace !== _trackerWorkspaceId) {
      _previousWorkspaceId = _trackerWorkspaceId;
      _trackerWorkspaceId = currentWorkspace;
    }
  }
  onEnabledChanged: {
    if (enabled && socketPath) {
      eventStreamSocket.connected = true;
      requestSocket.connected = true;
      _startupKick.start();
    } else {
      eventStreamSocket.connected = false;
      requestSocket.connected = false;
    }
  }

  Socket {
    id: eventStreamSocket

    connected: root.enabled && !!root.socketPath
    path: root.socketPath

    parser: SplitParser {
      splitMarker: "\n"

      onRead: line => {
        if (!line)
          return;
        try {
          const evt = JSON.parse(line);
          if (evt.WorkspacesChanged) {
            root.updateWorkspaces(evt.WorkspacesChanged.workspaces);
          } else if (evt.WorkspaceActivated) {
            root.updateSingleFocus(evt.WorkspaceActivated.id);
          }
        } catch (e) {
          Logger.log("WorkspaceImpl(Niri)", `Parse error: ${e}`);
        }
      }
    }

    onConnectionStateChanged: if (connected)
      write('"EventStream"\n')
  }

  Socket {
    id: requestSocket

    connected: root.enabled && !!root.socketPath
    path: root.socketPath
  }

  Timer {
    id: _startupKick

    interval: 200

    onTriggered: root.refresh()
  }
}
