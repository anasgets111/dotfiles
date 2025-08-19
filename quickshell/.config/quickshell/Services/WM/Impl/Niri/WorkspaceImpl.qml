pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.SystemInfo
import qs.Services as Services

// Niri Workspace Backend (logic only)
Singleton {
    id: niriWs
    // Services
    readonly property var logger: LoggerService
    readonly property var osd: OSDService
    // Only active when MainService says Niri is the WM
    readonly property bool active: (Services.MainService.currentWM === "niri")

    // Debounce for event-driven toasts
    property int _announceDebounceMs: 400
    property int _lastIdx: -1
    property double _lastAt: 0
    function _announce(idx) {
        if (!osd)
            return;
        var now = Date.now ? Date.now() : new Date().getTime();
        if (idx === _lastIdx && (now - _lastAt) < _announceDebounceMs)
            return;
        var outMsg = focusedOutput ? (focusedOutput + ": ") : "";
        osd.showInfo(outMsg + "Workspace " + idx);
        _lastIdx = idx;
        _lastAt = now;
    }

    // Enable/disable this backend (controlled by aggregator)
    property bool enabled: false

    // Unified surface properties
    property var workspaces: []
    property var outputsOrder: [] // [output names]
    property string focusedOutput: ""
    property var groupBoundaries: []
    property int currentWorkspace: 1
    property int previousWorkspace: 1

    // Hyprland-only no-ops for API parity
    property var specialWorkspaces: []
    property string activeSpecial: ""

    // Update helpers
    function updateWorkspaces(arr) {
        var oldIdx = currentWorkspace;
        // annotate
        arr.forEach(function (w) {
            w.populated = w.active_window_id !== null;
        });

        var f = arr.find(function (w) {
            return w.is_focused;
        });
        if (f)
            focusedOutput = f.output || "";

        var groups = {};
        arr.forEach(function (w) {
            var out = w.output || "";
            if (!groups[out])
                groups[out] = [];
            groups[out].push(w);
        });

        var outs = Object.keys(groups).sort(function (a, b) {
            if (a === focusedOutput)
                return -1;
            if (b === focusedOutput)
                return 1;
            return a.localeCompare(b);
        });
        outputsOrder = outs;

        var flat = [];
        var bounds = [];
        var acc = 0;
        outs.forEach(function (out) {
            groups[out].sort(function (a, b) {
                return a.idx - b.idx;
            });
            flat = flat.concat(groups[out]);
            acc += groups[out].length;
            if (acc > 0 && acc < arr.length)
                bounds.push(acc);
        });
        workspaces = flat;
        groupBoundaries = bounds;

        if (f && f.idx !== currentWorkspace) {
            previousWorkspace = currentWorkspace;
            currentWorkspace = f.idx;
            if (logger)
                logger.log("NiriWorkspace", `focus -> output='${focusedOutput}', idx=${currentWorkspace}`);
            _announce(currentWorkspace);
        }
    }

    function updateSingleFocus(id) {
        var w = workspaces.find(function (ww) {
            return ww.id === id;
        });
        if (!w)
            return;
        previousWorkspace = currentWorkspace;
        currentWorkspace = w.idx;
        focusedOutput = w.output || focusedOutput;
        workspaces.forEach(function (ww) {
            ww.is_focused = (ww.id === id);
            ww.is_active = (ww.id === id);
        });
        workspaces = workspaces; // trigger
        if (logger)
            logger.log("NiriWorkspace", `activate -> output='${focusedOutput}', idx=${currentWorkspace}`);
        _announce(currentWorkspace);
    }

    // Control methods
    function focusWorkspaceByIndex(idx) {
        if (!enabled || !active)
            return;
        switchProc.running = false;
        switchProc.command = ["niri", "msg", "action", "focus-workspace", String(idx)];
        switchProc.running = true;
    }

    function focusWorkspaceByWs(ws) {
        if (!enabled || !active || !ws)
            return;
        var out = ws.output || "";
        var idx = ws.idx;
        if (out && out !== focusedOutput) {
            var outEsc = out.replace(/'/g, "'\"'\"'");
            var script = "niri msg action focus-monitor '" + outEsc + "' && niri msg action focus-workspace " + idx;
            switchProc.running = false;
            switchProc.command = ["bash", "-lc", script];
            switchProc.running = true;
            return;
        }
        focusWorkspaceByIndex(idx);
    }

    function toggleSpecial(_name) {
    // Niri has no special workspaces; noop
    }

    function refresh() {
        if (!enabled || !active)
            return;
        seedProcWorkspaces.running = true;
    }

    // Processes
    Process {
        id: seedProcWorkspaces
        running: false
        command: ["niri", "msg", "--json", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(text);
                    if (j.Workspaces)
                        niriWs.updateWorkspaces(j.Workspaces.workspaces);
                } catch (e) {}
            }
        }
    }

    Process {
        id: eventProcNiri
        running: niriWs.enabled && niriWs.active
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (seg) {
                if (!seg)
                    return;
                try {
                    var evt = JSON.parse(seg);
                    if (evt.WorkspacesChanged)
                        niriWs.updateWorkspaces(evt.WorkspacesChanged.workspaces);
                    else if (evt.WorkspaceActivated)
                        niriWs.updateSingleFocus(evt.WorkspaceActivated.id);
                } catch (e) {}
            }
        }
    }

    Process {
        id: switchProc
        command: ["niri", "msg", "workspace", "1"]
    }

    onEnabledChanged: if (enabled && active)
        refresh()
    else {
        seedProcWorkspaces.running = false;
    }
}
