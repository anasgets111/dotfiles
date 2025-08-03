import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panelWindow

    property string mainMonitorName: Quickshell.env("MAINMON") || ""

    property bool normalWorkspacesExpanded: false

    Timer {
        id: remapIfHidden
        interval: 350
        repeat: false
        onTriggered: {
            if (!panelWindow.visible && panelWindow.screen) {
                panelWindow.visible = true;
            }
            panelWindow.pickScreen();
        }
    }

    function triggerRemap() {
        remapIfHidden.restart();
    }

    function pickScreen() {
        const screens = Quickshell.screens || [];
        const target = mainMonitorName ? screens.find(s => s && (s.name === mainMonitorName || s.model === mainMonitorName)) : null;
        panelWindow.screen = target || screens[0];
    }

    implicitWidth: panelWindow.screen.width
    implicitHeight: panelWindow.screen.height
    exclusiveZone: Theme.panelHeight
    screen: Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:bar:blur"
    WlrLayershell.layer: WlrLayer.Top
    color: Theme.panelWindowColor

    Component.onCompleted: pickScreen()

    // On visibility toggles, debounce remap
    onVisibleChanged: triggerRemap()

    Connections {
        target: Quickshell
        function onScreensChanged() {
            panelWindow.triggerRemap();
        }
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
