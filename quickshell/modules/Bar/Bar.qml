import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

PanelWindow {
    id: panelitemWidth

    // Panel placement
    screen: Quickshell.screens[0]
    mask: Region { item: panelRect }
    color: Theme.panelWindowColor
    implicitWidth: Screen.width
    margins { left: Theme.panelMargin; right: Theme.panelMargin; top: 0 }
    implicitHeight: Theme.panelHeight
    exclusiveZone: implicitHeight
    WlrLayershell.namespace: "quickshell:bar:blur"
    anchors { top: true; left: true; right: true }

    Rectangle {
        id: panelRect
        anchors.fill: parent
        color: Theme.bgColor
        radius: Theme.panelRadius

        // Left side - workspaces and idle inhibitor
        LeftSide {
            id: leftSide
            anchors {
                left: parent.left
                leftMargin: Theme.panelMargin
                verticalCenter: parent.verticalCenter
            }
        }

        // Center side - placeholder for center content
        CenterSide {
            id: centerSide
            anchors {
                centerIn: parent
            }
        }

        // Right side - placeholder for right content
        RightSide {
            id: rightSide
            anchors {
                right: parent.right
                rightMargin: Theme.panelMargin
                verticalCenter: parent.verticalCenter
            }
        }
    }
}
