pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.Utils

Singleton {
  id: root

  property string activeSpecial: ""
  property int currentWorkspace: 1
  property int currentWorkspaceId: -1
  property bool enabled: MainService.ready && MainService.currentWM === "niri"
  property string focusedOutput: ""
  property var groupBoundaries: []
  property var outputsOrder: []
  property int previousWorkspace: 1
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
  property var specialWorkspaces: []
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

  function focusWorkspaceByWs(ws) {
    if (!enabled || !ws)
      return;
    if (ws.output && ws.output !== focusedOutput) {
      send({
        Action: {
          FocusMonitor: {
            reference: {
              Name: ws.output
            }
          }
        }
      });
    }
    focusWorkspaceById(ws.id);
  }

  function refresh() {
    if (!enabled || !socketPath)
      return;
    eventStreamSocket.connected = false;
    requestSocket.connected = false;
    eventStreamSocket.connected = true;
    requestSocket.connected = true;
  }

  function send(request) {
    if (enabled && requestSocket.connected)
      requestSocket.write(JSON.stringify(request) + "\n");
  }

  // Transform raw Niri workspace to unified structure: { id, idx, focused, populated, output, name? }
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

  function toggleSpecial(_name) {
  } // Niri doesn't support special workspaces


  function updateSingleFocus(id) {
    let foundIdx = -1;
    for (let i = 0; i < workspaces.length; i++) {
      const ws = workspaces[i];
      const isFocused = ws.id === id;
      if (ws.focused !== isFocused)
        ws.focused = isFocused;
      if (isFocused)
        foundIdx = i;
    }

    if (foundIdx < 0)
      return;

    const foundWs = workspaces[foundIdx];
    if (foundWs.idx !== currentWorkspace) {
      root.previousWorkspace = currentWorkspace;
      root.currentWorkspace = foundWs.idx;
    }
    root.currentWorkspaceId = foundWs.id;
    root.focusedOutput = foundWs.output ?? focusedOutput;
    root.workspacesChanged(); // Trigger binding updates
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

    if (focusedWs && focusedWs.idx !== currentWorkspace) {
      root.previousWorkspace = currentWorkspace;
      root.currentWorkspace = focusedWs.idx;
      root.currentWorkspaceId = focusedWs.id;
    }
  }

  Component.onCompleted: if (enabled)
    _startupKick.start()
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
          Logger.log("NiriWs", "Parse error: " + e);
        }
      }
    }

    onConnectionStateChanged: {
      if (connected)
        write('"EventStream"\n');
    }
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
