pragma Singleton
import QtQml
import QtQuick
import Quickshell
import qs.Services
import qs.Services.SystemInfo
import qs.Services.Utils
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: ws

  readonly property int _announceCoalesceMs: 200
  readonly property int _globalMinIntervalMs: 800
  property string _lastKey: ""
  property string _lastSpecial: ""
  property double _lastToastAt: 0
  property int _pendingIdx: -1
  property string _pendingOutput: ""
  readonly property var backend: (MainService.currentWM === "hyprland" ? Hypr.WorkspaceImpl : (MainService.currentWM === "niri" ? Niri.WorkspaceImpl : null))
  readonly property string activeSpecial: backend ? backend.activeSpecial : ""
  readonly property int currentWorkspace: backend ? backend.currentWorkspace : -1
  readonly property int currentWorkspaceId: (backend && backend.currentWorkspaceId !== undefined) ? backend.currentWorkspaceId : -1
  readonly property string focusedOutput: backend ? backend.focusedOutput : ""
  readonly property var groupBoundaries: backend ? backend.groupBoundaries : []
  readonly property var outputsOrder: backend ? backend.outputsOrder : []
  readonly property int previousWorkspace: backend ? backend.previousWorkspace : -1
  readonly property var specialWorkspaces: backend ? backend.specialWorkspaces : []
  readonly property var workspaces: backend ? backend.workspaces : []

  function _announce(idx, out) {
    if (!OSDService || typeof idx !== "number" || idx < 1)
      return;
    const now = Date.now();
    const outName = (out !== undefined) ? out : ws.focusedOutput;
    const key = (outName || "") + "#" + idx;
    if (key === _lastKey)
      return;
    const prefix = (outName && outName.length > 0) ? (outName + ": ") : "";
    OSDService.showInfo(prefix + "Workspace " + idx);
    _lastKey = key;
    _lastToastAt = now;
  }
  function _scheduleAnnounce() {
    if (ws.currentWorkspace > 0) {
      ws._pendingIdx = ws.currentWorkspace;
      ws._pendingOutput = ws.focusedOutput || "";
      _announceTimer.restart();
    }
  }
  function focusWorkspaceByIndex(idx) {
    if (backend?.focusWorkspaceByIndex)
      backend.focusWorkspaceByIndex(idx);
  }
  function focusWorkspaceByWs(wsObj) {
    if (!backend || !wsObj)
      return;
    if (backend.focusWorkspaceByWs)
      backend.focusWorkspaceByWs(wsObj);
    else if (backend.focusWorkspaceByObject)
      backend.focusWorkspaceByObject(wsObj);
  }
  function refresh() {
    backend?.refresh();
  }
  function toggleSpecial(name) {
    backend?.toggleSpecial(name);
  }

  onActiveSpecialChanged: {
    if (!ws.backend)
      return;
    const sp = ws.activeSpecial || "";
    if (sp && sp !== ws._lastSpecial) {
      ws._lastSpecial = sp;
      Logger.log("Workspace", "special -> name='" + sp + "'");
      OSDService.showInfo("Special " + sp);
    } else if (!sp) {
      ws._lastSpecial = "";
    }
  }
  onCurrentWorkspaceChanged: if (ws.backend)
    ws._scheduleAnnounce()
  onFocusedOutputChanged: if (ws.backend)
    ws._scheduleAnnounce()

  Timer {
    id: _announceTimer
    interval: ws._announceCoalesceMs
    repeat: false
    onTriggered: {
      const idx = ws._pendingIdx;
      const out = ws._pendingOutput;
      if (idx > 0) {
        const key = (out || "") + "#" + idx;
        if (key !== ws._lastKey) {
          const now = Date.now();
          const since = now - ws._lastToastAt;
          if (since < ws._globalMinIntervalMs) {
            _announceTimer.interval = Math.max(50, ws._globalMinIntervalMs - since);
            _announceTimer.restart();
            return;
          }
          Logger.log("Workspace", "focus -> output='" + (out || "") + "', idx=" + idx);
          ws._announce(idx, out);
          _announceTimer.interval = ws._announceCoalesceMs;
        }
      }
    }
  }
  Binding {
    property: "enabled"
    target: Hypr.WorkspaceImpl
    value: MainService.ready && (ws.backend === Hypr.WorkspaceImpl)
  }
  Binding {
    property: "enabled"
    target: Niri.WorkspaceImpl
    value: MainService.ready && (ws.backend === Niri.WorkspaceImpl)
  }
}
