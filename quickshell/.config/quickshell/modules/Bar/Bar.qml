import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panelWindow

    // Read target monitor name from environment once (falls back to empty string)
    property string mainMonitorName: (Quickshell.env && Quickshell.env.MAINMON) ? Quickshell.env.MAINMON : ""

    // Helper to resolve a screen by name from Quickshell.screens
    function resolveScreenByName(name) {
        if (!name || !Quickshell.screens || Quickshell.screens.length === 0)
            return null;
        for (let i = 0; i < Quickshell.screens.length; i++) {
            const s = Quickshell.screens[i];
            if (s && (s.name === name || s.model === name || s.manufacturer + " " + s.model === name))
                return s;
        }
        return null;
    }

    // Ensure we pick the desired screen when available, else a safe fallback
    function selectTargetScreen() {
        const desired = resolveScreenByName(mainMonitorName);
        if (desired) {
            panelWindow.screen = desired;
        } else if (Quickshell.screens && Quickshell.screens.length > 0) {
            panelWindow.screen = Quickshell.screens[0];
        }
    }

    property bool normalWorkspacesExpanded: false

    implicitWidth: panelWindow.screen.width
    implicitHeight: panelWindow.screen.height
    exclusiveZone: Theme.panelHeight
    screen: Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:bar:blur"
    WlrLayershell.layer: WlrLayer.Top
    color: Theme.panelWindowColor

    // Re-evaluate on startup and whenever screens list changes
    Component.onCompleted: selectTargetScreen()
    Connections {
        target: Quickshell
        function onScreensChanged() { panelWindow.selectTargetScreen(); }
    }

    anchors {
        top: true
        left: true
        right: true
    }

    Rectangle {
        id: panelRect

        width: parent.width
        height: Theme.panelHeight
        color: Theme.bgColor
        anchors.top: parent.top
        anchors.left: parent.left
    }

    LeftSide {
        normalWorkspacesExpanded: panelWindow.normalWorkspacesExpanded
        onNormalWorkspacesExpandedChanged: panelWindow.normalWorkspacesExpanded = normalWorkspacesExpanded

        anchors {
            left: panelRect.left
            leftMargin: Theme.panelMargin
            verticalCenter: panelRect.verticalCenter
        }
    }

    CenterSide {
        anchors.centerIn: panelRect
        normalWorkspacesExpanded: panelWindow.normalWorkspacesExpanded
    }

    RightSide {
        anchors {
            right: panelRect.right
            rightMargin: Theme.panelMargin
            verticalCenter: panelRect.verticalCenter
        }
    }

    Item {
        id: bottomCuts

        width: parent.width
        height: Theme.panelRadius
        anchors.top: panelRect.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        RoundCorner {
            anchors.left: parent.left
            anchors.top: parent.top
            size: Theme.panelRadius
            color: Theme.bgColor
            corner: 2
            rotation: 90
        }

        RoundCorner {
            anchors.right: parent.right
            anchors.top: parent.top
            size: Theme.panelRadius
            color: Theme.bgColor
            corner: 3
            rotation: -90
        }
    }

    mask: Region {
        item: panelRect
    }
}
