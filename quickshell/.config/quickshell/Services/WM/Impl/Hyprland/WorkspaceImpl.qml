pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Services as Services

// Hyprland Workspace Backend (logic only)
Singleton {
    id: hyprWs

    readonly property bool active: Services.MainService.ready && Services.MainService.currentWM === "hyprland"
    property bool enabled: hyprWs.active

    // Normalized properties (match WorkspaceService API)
    // 1..10 fixed list for normal workspaces
    property var workspaces: []
    // Special workspaces (Hyprland negative IDs)
    property var specialWorkspaces: []
    property string activeSpecial: ""

    property int currentWorkspace: 1
    property int previousWorkspace: 1

    // Niri-specific no-ops to keep unified surface
    property var outputsOrder: []
    property var groupBoundaries: []
    property string focusedOutput: ""

    // Recompute lists from Hyprland state
    function recompute() {
        try {
            var arr = Hyprland.workspaces ? (Hyprland.workspaces.values || Hyprland.workspaces) : [];
            if (!arr)
                arr = [];

            const map = arr.reduce(function (m, w) {
                m[w.id] = w;
                return m;
            }, {});

            const normal = Array.from({
                "length": 10
            }, function (_unused, i) {
                const id = i + 1;
                const w = map[id];
                return {
                    "id": id,
                    "focused": !!(w && w.focused),
                    "populated": !!w
                };
            });
            hyprWs.workspaces = normal;

            const specials = [];
            for (let i = 0; i < arr.length; ++i) {
                const ws = arr[i];
                if (ws.id < 0)
                    specials.push(ws);
            }
            hyprWs.specialWorkspaces = specials;

            // set current workspace from focused entry if present
            const f = arr.find(function (w) {
                return !!w.focused && w.id > 0;
            });
            if (f && f.id !== hyprWs.currentWorkspace) {
                hyprWs.previousWorkspace = hyprWs.currentWorkspace;
                hyprWs.currentWorkspace = f.id;
            }
        } catch (e)
        // keep state as-is on parse errors
        {}
    }

    // Control methods
    function focusWorkspaceByIndex(idx) {
        if (!enabled || !active)
            return;
        Hyprland.dispatch("workspace " + idx);
    }

    function focusWorkspaceByWs(ws) {
        if (!ws)
            return;
        focusWorkspaceByIndex(ws.id);
    }

    function toggleSpecial(name) {
        if (!enabled || !active)
            return;
        if (!name)
            return;
        Hyprland.dispatch("togglespecialworkspace " + name);
    }

    function refresh() {
        if (!active)
            return;
        recompute();
    }

    // Track raw Hyprland events
    Connections {
        // Only attach to Hyprland signals when this backend is both enabled and active.
        // This prevents handling events from other WMs when currentWM changes.
        target: hyprWs.enabled ? Hyprland : null
        enabled: hyprWs.enabled
        function onRawEvent(evt) {
            if (!hyprWs.enabled)
                return;

            if (!evt || !evt.name)
                return;

            if (evt.name === "workspace") {
                const args = evt.parse ? evt.parse(2) : (evt.data ? evt.data.split(",") : []);
                const newId = parseInt(args && args[0]);
                if (newId && newId !== hyprWs.currentWorkspace) {
                    hyprWs.previousWorkspace = hyprWs.currentWorkspace;
                    hyprWs.currentWorkspace = newId;
                }
                // If switching to a normal workspace, clear active special indicator
                if (newId && newId > 0)
                    hyprWs.activeSpecial = "";
                hyprWs.recompute();
            } else if (evt.name === "activespecial") {
                const sp = evt.data ? evt.data.split(",")[0] : "";
                hyprWs.activeSpecial = sp;
                // specials might have changed focus state labels too
                hyprWs.recompute();
            } else if (evt.name === "destroyworkspace" || evt.name === "createworkspace") {
                hyprWs.recompute();
            }
        }
    }

    // Initialize with current state when enabled flips on
    onEnabledChanged: if (enabled)
        recompute()

    // If `active` changes (MainService.currentWM changed), recompute and ensure
    // connections are detached when not active.
    onActiveChanged: {
        if (active) {
            recompute();
        } else {
            // Clear state when not active to avoid stale data shown by other backends
            hyprWs.workspaces = [];
            hyprWs.specialWorkspaces = [];
            hyprWs.activeSpecial = "";
            hyprWs.currentWorkspace = 1;
            hyprWs.previousWorkspace = 1;
        }
    }
}
