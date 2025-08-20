pragma Singleton
import QtQuick
import Quickshell
import QtQml
import qs.Services
import qs.Services.SystemInfo
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

// Unified Workspace Service that forwards to Hyprland or Niri implementation
Singleton {
    id: ws

    // Detect session
    readonly property bool isHyprland: (MainService.currentWM === "hyprland")
    readonly property bool isNiri: (MainService.currentWM === "niri")

    // Single backend selector for simpler forwarding
    readonly property var backend: isHyprland ? Hypr.WorkspaceImpl : (isNiri ? Niri.WorkspaceImpl : null)

    // Common services for logging and OSD
    readonly property var logger: LoggerService
    readonly property var osd: OSDService

    // Unified announce helper with coalescing + distinct-until-changed (keyed by output#index)
    property int _announceCoalesceMs: 200
    property int _globalMinIntervalMs: 800
    property string _lastKey: ""
    property double _lastToastAt: 0
    function _announce(idx, out) {
        if (!osd || !idx || idx < 1)
            return;
        const now = Date.now ? Date.now() : new Date().getTime();
        const outName = (out !== undefined) ? out : ws.focusedOutput;
        const key = (outName || "") + "#" + idx;
        if (key === _lastKey)
            return; // no repeat announcements for same state
        const prefix = (outName && outName.length > 0) ? (outName + ": ") : "";
        osd.showInfo(prefix + "Workspace " + idx);
        _lastKey = key;
        _lastToastAt = now;
    }

    // Coalescer state
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
                        // rate-limit: try again after remaining time
                        _announceTimer.interval = Math.max(50, ws._globalMinIntervalMs - since);
                        _announceTimer.restart();
                        return;
                    }
                    if (ws.logger)
                        ws.logger.log("Workspace", "focus -> output='" + (out || "") + "', idx=" + idx);
                    ws._announce(idx, out);
                    // restore default coalesce interval
                    _announceTimer.interval = ws._announceCoalesceMs;
                }
            }
        }
    }

    // Enable the right backend (declarative)
    Binding {
        target: Hypr.WorkspaceImpl
        property: "enabled"
        value: ws.isHyprland
    }
    Binding {
        target: Niri.WorkspaceImpl
        property: "enabled"
        value: ws.isNiri
    }

    // Exposed unified properties (forward to the active backend; keep defaults)
    property var workspaces: backend ? backend.workspaces : []
    property var specialWorkspaces: backend ? backend.specialWorkspaces : []
    property string activeSpecial: backend ? backend.activeSpecial : ""
    property int currentWorkspace: backend ? backend.currentWorkspace : -1
    property int previousWorkspace: backend ? backend.previousWorkspace : -1
    property var outputsOrder: backend ? backend.outputsOrder : []
    property var groupBoundaries: backend ? backend.groupBoundaries : []
    property string focusedOutput: backend ? backend.focusedOutput : ""

    // Methods
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

    // Centralized, WM-agnostic logs + OSD announcements
    onCurrentWorkspaceChanged: if (ws.backend)
        ws._scheduleAnnounce()

    // If output changes during a cross-output switch, update and re-coalesce
    onFocusedOutputChanged: if (ws.backend)
        ws._scheduleAnnounce()

    // Prevent duplicate special announcements
    property string _lastSpecial: ""
    onActiveSpecialChanged: {
        if (!ws.backend)
            return;
        const sp = ws.activeSpecial || "";
        if (sp && sp !== ws._lastSpecial) {
            ws._lastSpecial = sp;
            if (ws.logger)
                ws.logger.log("Workspace", "special -> name='" + sp + "'");
            if (ws.osd)
                ws.osd.showInfo("Special " + sp);
        } else if (!sp) {
            // reset so next activation of same special is announced again
            ws._lastSpecial = "";
        }
    }

    // Reset dedupe/coalesce state when backend switches (e.g., WM changed)
    onBackendChanged: {
        ws._lastKey = "";
        ws._lastToastAt = 0;
        ws._pendingIdx = -1;
        ws._pendingOutput = "";
        ws._lastSpecial = "";
        _announceTimer.stop();
    }
}
