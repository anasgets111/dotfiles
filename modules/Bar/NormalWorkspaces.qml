import QtQuick
import Quickshell.Hyprland

Item {
    id: normalWorkspaces
    width: normalWorkspacesRow.width
    height: normalWorkspacesRow.height

    // Shared styling properties (inherited from parent)
    property string fontFamily: parent.fontFamily || "CaskaydiaCove Nerd Font Propo"
    property int wsWidth: parent.wsWidth || 32
    property int wsHeight: parent.wsHeight || 24
    property int wsRadius: parent.wsRadius || 15
    property color activeColor: parent.activeColor || "#4a9eff"
    property color inactiveColor: parent.inactiveColor || "#333333"
    property color borderColor: parent.borderColor || "#555555"
    property color textActiveColor: parent.textActiveColor || "#ffffff"
    property color textInactiveColor: parent.textInactiveColor || "#cccccc"
    property int animationDuration: parent.animationDuration || 250
    property int borderWidth: parent.borderWidth || 2
    property int fontSize: parent.fontSize || 12

    // State tracking
    property bool normalWorkspacesHovered: false

    // Delegate for normal (positive ID) workspaces
    Component {
        id: normalWorkspaceDelegate
        Rectangle {
            property var ws: modelData
            property bool shouldShow: ws.id >= 0 && (ws.active || normalWorkspaces.normalWorkspacesHovered)

            width: shouldShow ? wsWidth : 0
            height: wsHeight
            radius: wsRadius
            color: ws.active ? activeColor : inactiveColor
            border.color: borderColor
            border.width: borderWidth
            opacity: shouldShow ? 1.0 : 0.0

            Behavior on width {
                NumberAnimation { duration: animationDuration; easing.type: Easing.InOutQuad }
            }
            Behavior on opacity {
                NumberAnimation { duration: animationDuration; easing.type: Easing.InOutQuart }
            }
            Behavior on color {
                ColorAnimation { duration: animationDuration; easing.type: Easing.InOutQuad }
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
                font.pixelSize: fontSize
                font.family: fontFamily
            }
        }
    }

    // Hover area for expand/collapse functionality
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: normalWorkspaces.normalWorkspacesHovered = true
        onExited:  normalWorkspaces.normalWorkspacesHovered = false
    }

    // Normal workspaces row
    Row {
        id: normalWorkspacesRow
        spacing: 8
        Repeater {
            model: Hyprland.workspaces
            delegate: normalWorkspaceDelegate
        }
    }

    // Fallback when no workspaces
    Text {
        visible: Hyprland.workspaces.length === 0
        text:    "No workspaces"
        color:   textInactiveColor
        font.pixelSize: fontSize
        font.family: fontFamily
    }
}
