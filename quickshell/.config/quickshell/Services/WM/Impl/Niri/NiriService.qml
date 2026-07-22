pragma Singleton
import QtQuick
import Quickshell
import qs.Services.Utils

// Canonical state replicated from Niri's event stream, plus its serialized
// request channel. Consumers bind to the current state and can load at any time.
Singleton {
  id: root

  property var _replyQueue: []
  readonly property string currentLayout: layouts[currentLayoutIndex] ?? ""
  property int currentLayoutIndex: -1
  property var layouts: []
  readonly property bool requestConnected: requestSocket.connected
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
  property var windows: []
  property var workspaces: []

  signal configLoaded

  function _activateWorkspaces(source: var, activation: var): var {
    const activated = source.find(workspace => workspace.id === activation.id);
    if (!activated)
      return source;
    return source.map(workspace => Object.assign({}, workspace, {
        is_active: workspace.output === activated.output ? workspace.id === activation.id : workspace.is_active,
        is_focused: activation.focused ? workspace.id === activation.id : workspace.is_focused
      }));
  }
  function _parse(message: string): var {
    if (!message)
      return null;
    try {
      return JSON.parse(message);
    } catch (error) {
      Logger.warn("NiriService", `Parse error: ${error}`);
      return null;
    }
  }
  function _selfCheck(): bool {
    const workspaces = _activateWorkspaces([
      {
        id: 1,
        output: "A",
        is_active: true,
        is_focused: true
      },
      {
        id: 2,
        output: "B",
        is_active: false,
        is_focused: false
      },
      {
        id: 3,
        output: "B",
        is_active: true,
        is_focused: false
      }
    ], {
      id: 2,
      focused: true
    });
    return workspaces[0].is_active && !workspaces[0].is_focused && workspaces[1].is_active && workspaces[1].is_focused && !workspaces[2].is_active;
  }
  function _setLayoutIndex(index: var): void {
    currentLayoutIndex = Number.isInteger(index) && index >= 0 && index < layouts.length ? index : -1;
  }
  function handleEvent(event: var): void {
    if (event.WorkspacesChanged) {
      workspaces = Array.isArray(event.WorkspacesChanged.workspaces) ? event.WorkspacesChanged.workspaces : [];
    } else if (event.WorkspaceActivated) {
      workspaces = _activateWorkspaces(workspaces, event.WorkspaceActivated);
    } else if (event.WindowsChanged) {
      windows = Array.isArray(event.WindowsChanged.windows) ? event.WindowsChanged.windows : [];
    } else if (event.WindowOpenedOrChanged) {
      const changedWindow = event.WindowOpenedOrChanged.window;
      const index = windows.findIndex(window => window.id === changedWindow.id);
      windows = index < 0 ? [...windows, changedWindow] : windows.map((window, currentIndex) => currentIndex === index ? changedWindow : window);
    } else if (event.WindowClosed) {
      windows = windows.filter(window => window.id !== event.WindowClosed.id);
    } else if (event.KeyboardLayoutsChanged) {
      const layoutInfo = event.KeyboardLayoutsChanged.keyboard_layouts;
      layouts = (Array.isArray(layoutInfo?.names) ? layoutInfo.names : []).map(name => String(name ?? "").trim()).filter(Boolean);
      _setLayoutIndex(layoutInfo?.current_idx);
    } else if (event.KeyboardLayoutSwitched) {
      _setLayoutIndex(event.KeyboardLayoutSwitched.idx);
    } else if (event.ConfigLoaded) {
      configLoaded();
    }
  }
  function request(message: var, callback: var): void {
    if (!requestSocket.connected) {
      callback?.(null);
      return;
    }
    _replyQueue.push(typeof callback === "function" ? callback : null);
    requestSocket.write((typeof message === "string" ? message : JSON.stringify(message)) + "\n");
    requestSocket.flush();
  }

  Component.onCompleted: console.assert(_selfCheck(), "NiriService self-check failed")

  NiriSocket {
    eventStream: true
    path: root.socketPath

    onLineRead: message => {
      const event = root._parse(String(message ?? "").trim());
      if (event)
        root.handleEvent(event);
    }
  }
  NiriSocket {
    id: requestSocket

    path: root.socketPath

    onConnectedChanged: if (!connected)
      while (root._replyQueue.length)
        root._replyQueue.shift()?.(null)
    onLineRead: message => {
      const callback = root._replyQueue.shift();
      const reply = root._parse(String(message ?? "").trim());
      if (reply?.Err)
        Logger.warn("NiriService", `Request failed: ${JSON.stringify(reply.Err)}`);
      callback?.(reply);
    }
  }
}
