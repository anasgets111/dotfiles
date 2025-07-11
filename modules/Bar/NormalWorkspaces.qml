import QtQuick
import Quickshell.Hyprland
import "."

Item {
    id: normalWorkspaces
    width: normalWorkspacesRow.width
    height: normalWorkspacesRow.height

    // State tracking
    property bool normalWorkspacesHovered: false

    // Delegate for normal (positive ID) workspaces
    Component {
        id: normalWorkspaceDelegate
        Rectangle {
            property var ws: modelData
            property bool shouldShow: ws.id >= 0 && (ws.active || normalWorkspaces.normalWorkspacesHovered)

            width: shouldShow ? Theme.itemWidth : 0
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: ws.active ? Theme.activeColor : Theme.inactiveColor

            opacity: shouldShow ? 1.0 : 0.0

            Behavior on width {
                NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.InOutQuad }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.InOutQuart }
            }
            Behavior on color {
                ColorAnimation { duration: Theme.animationDuration; easing.type: Easing.InOutQuad }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: shouldShow
                onClicked: Hyprland.dispatch("workspace " + ws.id)
            }

            Text {
                anchors.centerIn: parent
                text: ws.id
                color: ws.active ? Theme.textActiveColor : Theme.textInactiveColor
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                font.bold: true
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
        color:   Theme.textInactiveColor
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        font.bold: true
    }
}
