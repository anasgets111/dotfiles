pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Services.SystemInfo
import qs.Services as Services

// Hyprland Workspace Backend (logic only)
Singleton {
    id: hyprWs

    // Services
    readonly property var logger: LoggerService
    readonly property var osd: OSDService
    readonly property bool active: (Services.MainService.currentWM === "hyprland")

    // Enable/disable this backend (controlled by aggregator)
    property bool enabled: false

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

            var map = arr.reduce(function (m, w) {
                m[w.id] = w;
                return m;
            }, {});

            var normal = Array.from({
                "length": 10
            }, function (_unused, i) {
                var id = i + 1;
                var w = map[id];
                return {
                    "id": id,
                    "focused": !!(w && w.focused),
                    "populated": !!w
                };
            });
            workspaces = normal;

            var specials = [];
            for (var i = 0; i < arr.length; ++i) {
                var ws = arr[i];
                if (ws.id < 0)
                    specials.push(ws);
            }
            specialWorkspaces = specials;

            // set current workspace from focused entry if present
            var f = arr.find(function (w) {
                return !!w.focused && w.id > 0;
            });
            if (f && f.id !== currentWorkspace) {
                previousWorkspace = currentWorkspace;
                currentWorkspace = f.id;
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
        target: Hyprland
        enabled: hyprWs.enabled && hyprWs.active
        function onRawEvent(evt) {
            if (!hyprWs.enabled || !hyprWs.active)
                return;

            if (!evt || !evt.name)
                return;

            if (evt.name === "workspace") {
                var args = evt.parse ? evt.parse(2) : (evt.data ? evt.data.split(",") : []);
                var newId = parseInt(args && args[0]);
                if (newId && newId !== hyprWs.currentWorkspace) {
                    hyprWs.previousWorkspace = hyprWs.currentWorkspace;
                    hyprWs.currentWorkspace = newId;
                    if (hyprWs.logger)
                        hyprWs.logger.log("HyprWorkspace", `focus -> id=${newId}`);
                    if (hyprWs.osd && newId > 0)
                        hyprWs.osd.showInfo("Workspace " + newId);
                }
                // If switching to a normal workspace, clear active special indicator
                if (newId && newId > 0)
                    hyprWs.activeSpecial = "";
                hyprWs.recompute();
            } else if (evt.name === "activespecial") {
                var sp = evt.data ? evt.data.split(",")[0] : "";
                hyprWs.activeSpecial = sp;
                if (hyprWs.logger)
                    hyprWs.logger.log("HyprWorkspace", `special -> name='${sp}'`);
                if (hyprWs.osd && sp)
                    hyprWs.osd.showInfo("Special " + sp);
                // specials might have changed focus state labels too
                hyprWs.recompute();
            } else if (evt.name === "destroyworkspace" || evt.name === "createworkspace") {
                hyprWs.recompute();
            }
        }
    }

    // Initialize with current state when enabled flips on
    onEnabledChanged: if (enabled && active)
        recompute()
}
