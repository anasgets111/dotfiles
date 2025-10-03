pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
  id: niriWs

  readonly property bool active: MainService.ready && MainService.currentWM === "niri"
  // kept writable so facade Binding can override
  property bool enabled: niriWs.active

  // live state
  property string activeSpecial: ""
  property int currentWorkspace: 1
  property int currentWorkspaceId: -1
  property string focusedOutput: ""
  property var groupBoundaries: []
  property var outputsOrder: []
  property int previousWorkspace: 1
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""
  property var specialWorkspaces: []
  property var workspaces: []

  // control
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
    const w = workspaces.find(ww => ww.idx === idx);
    if (w)
      focusWorkspaceById(w.id);
  }
  function focusWorkspaceByWs(ws) {
    if (!enabled || !ws)
      return;
    const out = ws.output || "";
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
    if (!enabled || !socketPath)
      return;
    eventStreamSocket.connected = false;
    requestSocket.connected = false;
    eventStreamSocket.connected = true;
    requestSocket.connected = true;
  }

  // IPC helpers
  function send(request) {
    if (!enabled || !requestSocket.connected)
      return;
    requestSocket.write(JSON.stringify(request) + "\n");
  }
  function toggleSpecial(_name) { /* Niri: no-op */
  }

  function updateSingleFocus(id) {
    const w = workspaces.find(ww => ww.id === id);
    if (!w)
      return;
    niriWs.previousWorkspace = niriWs.currentWorkspace;
    niriWs.currentWorkspace = w.idx;
    niriWs.currentWorkspaceId = w.id;
    niriWs.focusedOutput = w.output || focusedOutput;
    workspaces.forEach(ww => {
      ww.is_focused = (ww.id === id);
      ww.is_active = (ww.id === id);
    });
    niriWs.workspaces = workspaces;
  }

  function updateWorkspaces(arr) {
    arr.forEach(w => {
      w.populated = w.active_window_id !== null;
    });

    const f = arr.find(w => w.is_focused);
    if (f)
      niriWs.focusedOutput = f.output || "";

    const groups = {};
    arr.forEach(w => {
      const out = w.output || "";
      if (!groups[out])
        groups[out] = [];
      groups[out].push(w);
    });

    const outs = Object.keys(groups).sort((a, b) => {
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
    outs.forEach(out => {
      groups[out].sort((a, b) => a.idx - b.idx);
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
      niriWs.currentWorkspaceId = f.id;
    }
  }

  Component.onCompleted: {
    if (enabled)
      _startupKick.start();
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

  // event stream
  Socket {
    id: eventStreamSocket
    connected: niriWs.enabled && !!niriWs.socketPath
    path: niriWs.socketPath

    parser: SplitParser {
      splitMarker: "\n"
      onRead: function (line) {
        if (!line)
          return;
        try {
          const evt = JSON.parse(line);
          if (evt.WorkspacesChanged) {
            niriWs.updateWorkspaces(evt.WorkspacesChanged.workspaces);
          } else if (evt.WorkspaceActivated) {
            niriWs.updateSingleFocus(evt.WorkspaceActivated.id);
          }
        } catch (e) {
          // Reset connection on parse error to clear buffer
          eventStreamSocket.connected = false;
          Qt.callLater(() => {
            eventStreamSocket.connected = niriWs.enabled && !!niriWs.socketPath;
          });
        }
      }
    }

    onConnectionStateChanged: {
      if (connected) {
        write('"EventStream"\n');
      }
    }
  }

  // request channel
  Socket {
    id: requestSocket
    connected: niriWs.enabled && !!niriWs.socketPath
    path: niriWs.socketPath
  }

  Timer {
    id: _startupKick
    interval: 200
    repeat: false
    onTriggered: if (niriWs.enabled)
      niriWs.refresh()
  }

  Component.onDestruction: {
    _startupKick.stop();
    eventStreamSocket.connected = false;
    requestSocket.connected = false;
  }
}
