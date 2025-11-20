pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.Utils

Singleton {
  id: root

  readonly property bool active: MainService.ready && MainService.currentWM === "niri"
  property string activeSpecial: ""
  property int currentWorkspace: 1
  property int currentWorkspaceId: -1
  property bool enabled: root.active
  property string focusedOutput: ""
  property var groupBoundaries: []
  property var outputsOrder: []
  property int previousWorkspace: 1
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""
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
    const w = workspaces.find(ws => ws.idx === idx);
    if (w)
      focusWorkspaceById(w.id);
  }

  function focusWorkspaceByWs(ws) {
    if (!enabled || !ws)
      return;
    const out = ws.output || "";
    if (out && out !== focusedOutput)
      send({
        Action: {
          FocusMonitor: {
            reference: {
              Name: out
            }
          }
        }
      });
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

  function toggleSpecial(_name) {
  } // Niri: no-op


  function updateSingleFocus(id) {
    const w = workspaces.find(ws => ws.id === id);
    if (!w)
      return;
    root.previousWorkspace = root.currentWorkspace;
    root.currentWorkspace = w.idx;
    root.currentWorkspaceId = w.id;
    root.focusedOutput = w.output || focusedOutput;

    // Create a new array to ensure change detection if needed,
    // though modifying objects in place works if they are QObjects.
    // Here they are JS objects, so we might need to trigger an update.
    // However, the previous code modified in place and reassigned root.workspaces.
    const newWorkspaces = workspaces.map(ws => {
      ws.is_focused = (ws.id === id);
      ws.is_active = (ws.id === id);
      return ws;
    });
    root.workspaces = newWorkspaces;
  }

  function updateWorkspaces(arr) {
    // Pre-process: populate 'populated' field
    for (let i = 0; i < arr.length; ++i) {
      arr[i].populated = arr[i].active_window_id !== null;
    }

    const focusedWs = arr.find(w => w.is_focused);
    if (focusedWs) {
      root.focusedOutput = focusedWs.output || "";
    }

    // Group by output
    const groups = new Map();
    for (const w of arr) {
      const out = w.output || "";
      if (!groups.has(out))
        groups.set(out, []);
      groups.get(out).push(w);
    }

    // Sort outputs: focused first, then alphabetical
    const sortedOutputs = Array.from(groups.keys()).sort((a, b) => {
      if (a === root.focusedOutput)
        return -1;
      if (b === root.focusedOutput)
        return 1;
      return a.localeCompare(b);
    });

    // Update outputsOrder only if changed to avoid unnecessary signal emissions
    if (JSON.stringify(root.outputsOrder) !== JSON.stringify(sortedOutputs)) {
      root.outputsOrder = sortedOutputs;
    }

    // Flatten and calculate boundaries
    const flat = [];
    const bounds = [];
    let accumulatedCount = 0;

    for (const out of sortedOutputs) {
      const wsList = groups.get(out);
      wsList.sort((a, b) => a.idx - b.idx);

      // Push all items
      for (const w of wsList)
        flat.push(w);

      accumulatedCount += wsList.length;
      // Add boundary if not the last group
      if (accumulatedCount < arr.length) {
        bounds.push(accumulatedCount);
      }
    }

    root.workspaces = flat;
    root.groupBoundaries = bounds;

    if (focusedWs && focusedWs.idx !== root.currentWorkspace) {
      root.previousWorkspace = root.currentWorkspace;
      root.currentWorkspace = focusedWs.idx;
      root.currentWorkspaceId = focusedWs.id;
    }
  }

  Component.onCompleted: {
    if (enabled)
      _startupKick.start();
  }
  Component.onDestruction: {
    _startupKick.stop();
    eventStreamSocket.connected = false;
    requestSocket.connected = false;
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
          Logger.log("NiriWs", "JSON parse error: " + e);
          // Only reconnect if it seems like a stream desync, but for now just log.
          // eventStreamSocket.connected = false;
          // Qt.callLater(() => {
          //   eventStreamSocket.connected = root.enabled && !!root.socketPath;
          // });
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
    repeat: false

    onTriggered: if (root.enabled)
      root.refresh()
  }
}
