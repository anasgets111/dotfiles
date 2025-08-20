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

    property bool enabled: niriWs.active

    // Announce/logging handled by abstract WorkspaceService
    property var workspaces: []
    property var outputsOrder: [] // [output names]
    property string focusedOutput: ""
    property var groupBoundaries: []
    property int currentWorkspace: 1
    property int previousWorkspace: 1

    property var specialWorkspaces: []
    property string activeSpecial: ""

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

    // Control methods
    function focusWorkspaceByIndex(idx) {
        if (!enabled)
            return;
        switchProc.running = false;
        switchProc.command = ["niri", "msg", "action", "focus-workspace", String(idx)];
        switchProc.running = true;
    }

    function focusWorkspaceByWs(ws) {
        if (!enabled || !ws)
            return;
        const out = ws.output || "";
        const idx = ws.idx;
        if (out && out !== focusedOutput) {
            const outEsc = out.replace(/'/g, "'\"'\"'");
            const script = "niri msg action focus-monitor '" + outEsc + "' && niri msg action focus-workspace " + idx;
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
        if (!enabled)
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
                    const j = JSON.parse(text);
                    if (j.Workspaces)
                        niriWs.updateWorkspaces(j.Workspaces.workspaces);
                } catch (e) {}
            }
        }
    }

    Process {
        id: eventProcNiri
        running: niriWs.enabled
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (seg) {
                if (!seg)
                    return;
                try {
                    const evt = JSON.parse(seg);
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

    onEnabledChanged: if (enabled)
        refresh()
    else {
        seedProcWorkspaces.running = false;
    }
}
