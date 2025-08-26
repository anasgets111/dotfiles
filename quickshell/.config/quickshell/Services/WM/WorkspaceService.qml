pragma Singleton
import QtQuick
import Quickshell
import QtQml
import qs.Services
import qs.Services.Utils
import qs.Services.SystemInfo
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
    id: ws

    readonly property var backend: (MainService.currentWM === "hyprland" ? Hypr.WorkspaceImpl : (MainService.currentWM === "niri" ? Niri.WorkspaceImpl : null))

    property var workspaces: backend ? backend.workspaces : []
    property var specialWorkspaces: backend ? backend.specialWorkspaces : []
    property string activeSpecial: backend ? backend.activeSpecial : ""
    property int currentWorkspace: backend ? backend.currentWorkspace : -1
    property int previousWorkspace: backend ? backend.previousWorkspace : -1
    property var outputsOrder: backend ? backend.outputsOrder : []
    property var groupBoundaries: backend ? backend.groupBoundaries : []
    property string focusedOutput: backend ? backend.focusedOutput : ""

    property int _announceCoalesceMs: 200
    property int _globalMinIntervalMs: 800
    property string _lastKey: ""
    property double _lastToastAt: 0
    function _announce(idx, out) {
        if (!OSDService || !idx || idx < 1)
            return;
        const now = Date.now ? Date.now() : new Date().getTime();
        const outName = (out !== undefined) ? out : ws.focusedOutput;
        const key = (outName || "") + "#" + idx;
        if (key === _lastKey)
            return; // no repeat announcements for same state
        const prefix = (outName && outName.length > 0) ? (outName + ": ") : "";
        OSDService.showInfo(prefix + "Workspace " + idx);
        _lastKey = key;
        _lastToastAt = now;
    }

    property int _pendingIdx: -1
    property string _pendingOutput: ""
    function _scheduleAnnounce() {
        if (ws.currentWorkspace && ws.currentWorkspace > 0) {
            ws._pendingIdx = ws.currentWorkspace;
            ws._pendingOutput = ws.focusedOutput || "";
            _announceTimer.restart();
        }
    }
    Timer {
        id: _announceTimer
        interval: ws._announceCoalesceMs
        repeat: false
        running: false
        onTriggered: {
            const idx = ws._pendingIdx;
            const out = ws._pendingOutput;
            if (idx > 0) {
                const key = (out || "") + "#" + idx;
                if (key !== ws._lastKey) {
                    const now = Date.now ? Date.now() : new Date().getTime();
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
        target: Hypr.WorkspaceImpl
        property: "enabled"
        value: MainService.ready && (ws.backend === Hypr.WorkspaceImpl)
    }
    Binding {
        target: Niri.WorkspaceImpl
        property: "enabled"
        value: MainService.ready && (ws.backend === Niri.WorkspaceImpl)
    }

    function focusWorkspaceByIndex(idx) {
        if (backend && backend.focusWorkspaceByIndex)
            backend.focusWorkspaceByIndex(idx);
    }
    function focusWorkspaceByWs(wsObj) {
        if (backend && backend.focusWorkspaceByWs)
            backend.focusWorkspaceByWs(wsObj);
    }
    function toggleSpecial(name) {
        if (backend && backend.toggleSpecial)
            backend.toggleSpecial(name);
    }
    function refresh() {
        if (backend && backend.refresh)
            backend.refresh();
    }

    onCurrentWorkspaceChanged: if (ws.backend)
        ws._scheduleAnnounce()

    onFocusedOutputChanged: if (ws.backend)
        ws._scheduleAnnounce()

    property string _lastSpecial: ""
    onActiveSpecialChanged: {
        if (!ws.backend)
            return;
        const sp = ws.activeSpecial || "";
        if (sp && sp !== ws._lastSpecial) {
            ws._lastSpecial = sp;
            Logger.log("Workspace", "special -> name='" + sp + "'");
            OSDService.showInfo("Special " + sp);
        } else if (!sp) {
            // reset so next activation of same special is announced again
            ws._lastSpecial = "";
        }
    }
}
