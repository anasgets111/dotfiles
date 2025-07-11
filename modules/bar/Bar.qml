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
        border.width: 3

        property bool normalWorkspacesHovered: false

        // Delegate for normal (positive ID) workspaces
        Component {
            id: normalWorkspaceDelegate
            Rectangle {
                property var ws: modelData
                property bool shouldShow: ws.id >= 0 && (ws.active || panelRect.normalWorkspacesHovered)

                // visible removed to allow unhover animation
                width: shouldShow ? wsWidth : 0
                height: wsHeight
                radius: wsRadius
                color: ws.active ? activeColor : inactiveColor
                border.color: borderColor
                border.width: 2
                opacity: shouldShow ? 1.0 : 0.0

                Behavior on width {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutQuart }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: shouldShow
                    onClicked: Hyprland.dispatch("workspace " + ws.id)
                }

                Text {
                    anchors.centerIn: parent
                    text: ws.id
                    color: ws.active ? textActiveColor : textInactiveColor
                    font.pixelSize: 12
                    font.family: fontFamily
                }
            }
        }

        // Delegate for special (negative ID) workspaces
        Component {
            id: specialWorkspaceDelegate
            Rectangle {
                property var ws: modelData

                visible: ws.id < 0
                width: wsWidth
                height: wsHeight
                radius: wsRadius
                color: ws.active ? activeColor : inactiveColor
                border.color: borderColor
                border.width: 2
                opacity: visible ? 1.0 : 0.0

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch(
                        "togglespecialworkspace " +
                        ws.name.replace("special:", "")
                    )
                }

                Text {
                    anchors.centerIn: parent
                    text: ws.name.replace("special:", "")
                    color: ws.active ? textActiveColor : textInactiveColor
                    font.pixelSize: 12
                    font.family: fontFamily
                }
            }
        }

        Row {
            id: workspaceRow
            anchors {
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            // Idle inhibitor for PowerSave
            IdleInhibitor {
                id: idleInhibitor
                anchors.verticalCenter: parent.verticalCenter
            }

            // Normal workspaces (hover to expand)
            Item {
                width: normalWorkspacesRow.width
                height: normalWorkspacesRow.height

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: panelRect.normalWorkspacesHovered = true
                    onExited:  panelRect.normalWorkspacesHovered = false
                }

                Row {
                    id: normalWorkspacesRow
                    spacing: 8
                    Repeater {
                        model: Hyprland.workspaces
                        delegate: normalWorkspaceDelegate
                    }
                }
            }

            // Special workspaces
            Repeater {
                model: Hyprland.workspaces
                delegate: specialWorkspaceDelegate
            }

            // Fallback when no workspaces
            Text {
                visible: Hyprland.workspaces.length === 0
                text:    "No workspaces"
                color:   textInactiveColor
                font.pixelSize: 12
                font.family: fontFamily
            }
        }
    }
}
