import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: panel

    // Shared styling properties
    property string fontFamily: "CaskaydiaCove Nerd Font Propo"
    property int wsWidth: 32
    property int wsHeight: 24
    property int wsRadius: 15
    property color activeColor: "#4a9eff"
    property color inactiveColor: "#333333"
    property color borderColor: "#555555"
    property color bgColor: "#1a1a1a"
    property color panelBorderColor: "#333333"
    property color textActiveColor: "#ffffff"
    property color textInactiveColor: "#cccccc"
    property int animationDuration: 250
    property int borderWidth: 2

    // Panel placement
    screen: Quickshell.screens[0]
    mask: Region { item: panelRect }
    color: "transparent"
    implicitWidth: Screen.width
    margins { left: 16; right: 16; top: 0 }
    implicitHeight: 40
    exclusiveZone: implicitHeight
    WlrLayershell.namespace: "quickshell:bar:blur"
    anchors { top: true; left: true; right: true }

    Rectangle {
        id: panelRect
        anchors.fill: parent
        color: bgColor
        radius: 15
        border.color: panelBorderColor
        border.width: borderWidth

        // Left side - workspaces and idle inhibitor
        LeftSide {
            id: leftSide
            anchors {
                left: parent.left
                leftMargin: 16
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
                rightMargin: 16
                verticalCenter: parent.verticalCenter
            }
        }
    }
}
