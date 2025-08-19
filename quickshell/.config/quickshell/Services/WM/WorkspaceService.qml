pragma Singleton
import QtQuick
import Quickshell
import QtQml
import qs.Services as Services
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

// Unified Workspace Service that forwards to Hyprland or Niri implementation
Singleton {
    id: ws

    // Detect session
    readonly property bool isHyprland: (Services.MainService.currentWM === "hyprland")
    readonly property bool isNiri: (Services.MainService.currentWM === "niri")

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

    // Exposed unified properties
    property var workspaces: isHyprland ? Hypr.WorkspaceImpl.workspaces : (isNiri ? Niri.WorkspaceImpl.workspaces : [])
    property var specialWorkspaces: isHyprland ? Hypr.WorkspaceImpl.specialWorkspaces : []
    property string activeSpecial: isHyprland ? Hypr.WorkspaceImpl.activeSpecial : ""
    property int currentWorkspace: isHyprland ? Hypr.WorkspaceImpl.currentWorkspace : (isNiri ? Niri.WorkspaceImpl.currentWorkspace : -1)
    property int previousWorkspace: isHyprland ? Hypr.WorkspaceImpl.previousWorkspace : (isNiri ? Niri.WorkspaceImpl.previousWorkspace : -1)
    property var outputsOrder: isNiri ? Niri.WorkspaceImpl.outputsOrder : []
    property var groupBoundaries: isNiri ? Niri.WorkspaceImpl.groupBoundaries : []
    property string focusedOutput: isNiri ? Niri.WorkspaceImpl.focusedOutput : ""

    // Methods
    function focusWorkspaceByIndex(idx) {
        if (isHyprland) {
            Hypr.WorkspaceImpl.focusWorkspaceByIndex(idx);
        } else if (isNiri) {
            Niri.WorkspaceImpl.focusWorkspaceByIndex(idx);
        }
    }
    function focusWorkspaceByWs(wsObj) {
        if (isHyprland) {
            Hypr.WorkspaceImpl.focusWorkspaceByWs(wsObj);
        } else if (isNiri) {
            Niri.WorkspaceImpl.focusWorkspaceByWs(wsObj);
        }
    }
    function toggleSpecial(name) {
        if (isHyprland) {
            Hypr.WorkspaceImpl.toggleSpecial(name);
        }
    }
    function refresh() {
        if (isHyprland) {
            Hypr.WorkspaceImpl.refresh();
        } else if (isNiri) {
            Niri.WorkspaceImpl.refresh();
        }
    }
}
