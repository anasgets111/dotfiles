pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

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
    workspaces.forEach(ws => {
      ws.is_focused = (ws.id === id);
      ws.is_active = (ws.id === id);
    });
    root.workspaces = workspaces;
  }

  function updateWorkspaces(arr) {
    arr.forEach(w => {
      w.populated = w.active_window_id !== null;
    });

    const f = arr.find(w => w.is_focused);
    if (f)
      root.focusedOutput = f.output || "";

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
    root.outputsOrder = outs;

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
    root.workspaces = flat;
    root.groupBoundaries = bounds;

    if (f && f.idx !== root.currentWorkspace) {
      root.previousWorkspace = root.currentWorkspace;
      root.currentWorkspace = f.idx;
      root.currentWorkspaceId = f.id;
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
          eventStreamSocket.connected = false;
          Qt.callLater(() => {
            eventStreamSocket.connected = root.enabled && !!root.socketPath;
          });
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
