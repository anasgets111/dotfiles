import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panelWindow

    property bool normalWorkspacesExpanded: false
    property string mainMonitor: Quickshell.env("MAINMON")
    implicitWidth: panelWindow.screen.width
    implicitHeight: panelWindow.screen.height
    exclusiveZone: Theme.panelHeight
    screen: Quickshell.screens.length > 1 ? Quickshell.screens[1] : Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:bar:blur"
    color: Theme.panelWindowColor

    Item {
        id: screenBinder
        property int debounceRestarts: 0
        function pickScreen() {
            const screens = Quickshell.screens || [];
            const target = panelWindow.mainMonitor ? screens.find(s => s && (s.name === panelWindow.mainMonitor || s.model === panelWindow.mainMonitor)) : null;
            return target || screens[0];
        }
        Timer {
            id: screenDebounce
            interval: 500
            repeat: false
            onTriggered: {
                const sel = screenBinder.pickScreen();
                if (!sel || panelWindow.screen !== sel) {
                    panelWindow.screen = sel;
                }
                postAssignCheck.restart();
            }
        }

        Timer {
            id: postAssignCheck
            interval: 160
            repeat: false
            onTriggered: {
                if (!panelWindow.visible && panelWindow.screen) {
                    remapIfHidden.start();
                }
            }
        }

        Timer {
            id: remapIfHidden
            interval: 350
            repeat: false
            onTriggered: {
                if (!panelWindow.visible && panelWindow.screen) {
                    panelWindow.visible = true;
                }
            }
        }

        Connections {
            target: Quickshell
            function onScreensChanged() {
                screenDebounce.restart();
            }
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
