import QtQuick
import Quickshell.Hyprland

Row {
    id: leftSide
    spacing: 8

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

    // State tracking
    property bool normalWorkspacesHovered: false
    property string activeSpecialWorkspace: ""

    // Track special workspace states via raw events
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial") {
                var data = event.data.split(",")
                if (data.length >= 2) {
                    var specialName = data[0]
                    leftSide.activeSpecialWorkspace = specialName
                }
            } else if (event.name === "workspace") {
                // Clear active special when switching to normal workspace
                var workspaceId = parseInt(event.data.split(",")[0])
                if (workspaceId > 0) {
                    leftSide.activeSpecialWorkspace = ""
                }
            }
        }
    }

    // Delegate for normal (positive ID) workspaces
    Component {
        id: normalWorkspaceDelegate
        Rectangle {
            property var ws: modelData
            property bool shouldShow: ws.id >= 0 && (ws.active || leftSide.normalWorkspacesHovered)

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
            property bool isActive: ws.name === leftSide.activeSpecialWorkspace

            visible: ws.id < 0
            width: wsWidth
            height: wsHeight
            radius: wsRadius
            color: isActive ? activeColor : inactiveColor
            border.color: "#555555"
            border.width: borderWidth
            opacity: visible ? 1.0 : 0.0

            // Smooth color transitions
            Behavior on color {
                ColorAnimation { duration: animationDuration; easing.type: Easing.InOutQuad }
            }

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
                color: isActive ? textActiveColor : textInactiveColor
                font.pixelSize: 12
                font.family: fontFamily

                // Smooth text color transition
                Behavior on color {
                    ColorAnimation { duration: animationDuration; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

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
            onEntered: leftSide.normalWorkspacesHovered = true
            onExited:  leftSide.normalWorkspacesHovered = false
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
