pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

// Niri Workspace Backend (logic only)
Singleton {
  id: niriWs

  readonly property bool active: MainService.ready && MainService.currentWM === "niri"
  property string activeSpecial: ""
  property int currentWorkspace: 1
  property bool enabled: niriWs.active
  property string focusedOutput: ""
  property var groupBoundaries: []
  property var outputsOrder: [] // [output names]
  property int previousWorkspace: 1

  // Niri IPC socket
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""
  property var specialWorkspaces: []

  // Announce/logging handled by abstract WorkspaceService
  property var workspaces: []

  // Control methods
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
    const w = workspaces.find(function (ww) {
      return ww.idx === idx;
    });
    if (w)
      focusWorkspaceById(w.id);
  }
  function focusWorkspaceByWs(ws) {
    if (!enabled || !ws)
      return;
    const out = ws.output || "";
    const idx = ws.idx;
    // If workspace lives on a different output, focus that monitor first, then workspace
    if (out && out !== focusedOutput) {
      send({
        Action: {
          FocusMonitor: {
            reference: {
              Name: out
            }
          }
        }
      });
    }
    focusWorkspaceById(ws.id);
  }
  function refresh() {
    // Reconnect event stream if needed; server will emit a snapshot
    if (!enabled || !socketPath)
      return;
    eventStreamSocket.connected = false;
    requestSocket.connected = false;
    eventStreamSocket.connected = true;
    requestSocket.connected = true;
  }

  // --- IPC helpers ---
  function send(request) {
    if (!enabled || !requestSocket.connected)
      return;
    requestSocket.write(JSON.stringify(request) + "\n");
  }
  function toggleSpecial(_name) {
  // Niri has no special workspaces; noop
  }
  function updateSingleFocus(id) {
    const w = workspaces.find(function (ww) {
      return ww.id === id;
    });
    if (!w)
      return;
    niriWs.previousWorkspace = niriWs.currentWorkspace;
    niriWs.currentWorkspace = w.idx;
    niriWs.focusedOutput = w.output || focusedOutput;
    workspaces.forEach(function (ww) {
      ww.is_focused = (ww.id === id);
      ww.is_active = (ww.id === id);
    });
    niriWs.workspaces = workspaces; // trigger
  }

  // Update helpers
  function updateWorkspaces(arr) {
    // annotate
    arr.forEach(function (w) {
      w.populated = w.active_window_id !== null;
    });

    const f = arr.find(function (w) {
      return w.is_focused;
    });
    if (f)
      niriWs.focusedOutput = f.output || "";

    const groups = {};
    arr.forEach(function (w) {
      const out = w.output || "";
      if (!groups[out])
        groups[out] = [];
      groups[out].push(w);
    });

    const outs = Object.keys(groups).sort(function (a, b) {
      if (a === focusedOutput)
        return -1;
      if (b === focusedOutput)
        return 1;
      return a.localeCompare(b);
    });
    niriWs.outputsOrder = outs;
    let flat = [];
    const bounds = [];
    let acc = 0;
    outs.forEach(function (out) {
      groups[out].sort(function (a, b) {
        return a.idx - b.idx;
      });
      flat = flat.concat(groups[out]);
      acc += groups[out].length;
      if (acc > 0 && acc < arr.length)
        bounds.push(acc);
    });
    niriWs.workspaces = flat;
    niriWs.groupBoundaries = bounds;

    if (f && f.idx !== niriWs.currentWorkspace) {
      niriWs.previousWorkspace = niriWs.currentWorkspace;
      niriWs.currentWorkspace = f.idx;
      // Logging + OSD handled in abstract service
    }
  }

  onEnabledChanged: {
    if (enabled && socketPath) {
      eventStreamSocket.connected = true;
      requestSocket.connected = true;
    } else {
      eventStreamSocket.connected = false;
      requestSocket.connected = false;
    }
  }

  // --- Sockets ---
  Socket {
    id: eventStreamSocket

    connected: niriWs.enabled && !!niriWs.socketPath
    path: niriWs.socketPath

    parser: SplitParser {
      splitMarker: "\n"

      onRead: function (line) {
        if (!line)
          return;
        const evt = JSON.parse(line);
        if (evt.WorkspacesChanged) {
          niriWs.updateWorkspaces(evt.WorkspacesChanged.workspaces);
        } else if (evt.WorkspaceActivated) {
          // evt.WorkspaceActivated may include { id, focused }
          niriWs.updateSingleFocus(evt.WorkspaceActivated.id);
        }
      }
    }

    onConnectionStateChanged: {
      if (connected) {
        // Subscribe to event stream
        write('"EventStream"\n');
      }
    }
  }
  Socket {
    id: requestSocket

    connected: niriWs.enabled && !!niriWs.socketPath
    path: niriWs.socketPath
  }
}
