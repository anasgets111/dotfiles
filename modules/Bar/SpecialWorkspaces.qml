import QtQuick
import Quickshell.Hyprland
import "."

Row {
    id: specialWorkspaces
    spacing: 8

    // Styling properties are now accessed from Theme singleton

    // State tracking
    property string activeSpecialWorkspace: ""

    // Track special workspace states via raw events
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial") {
                var data = event.data.split(",")
                if (data.length >= 2) {
                    var specialName = data[0]
                    specialWorkspaces.activeSpecialWorkspace = specialName
                }
            } else if (event.name === "workspace") {
                // Clear active special when switching to normal workspace
                var workspaceId = parseInt(event.data.split(",")[0])
                if (workspaceId > 0) {
                    specialWorkspaces.activeSpecialWorkspace = ""
                }
            }
        }
    }

    // Delegate for special (negative ID) workspaces
    Component {
        id: specialWorkspaceDelegate
        Rectangle {
            property var ws: modelData
            property bool isActive: ws.name === specialWorkspaces.activeSpecialWorkspace

            visible: ws.id < 0
            width: Theme.itemWidth
            height: Theme.itemHeight
            radius: Theme.wsRadius
            color: isActive ? Theme.activeColor : Theme.inactiveColor
            border.color: Theme.borderColor
            border.width: Theme.borderWidth
            opacity: visible ? 1.0 : 0.0

            // Smooth color transitions
            Behavior on color {
                ColorAnimation { duration: Theme.animationDuration; easing.type: Easing.InOutQuad }
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
                color: isActive ? Theme.textActiveColor : Theme.textInactiveColor
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily

                // Smooth text color transition
                Behavior on color {
                    ColorAnimation { duration: Theme.animationDuration; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    // Special workspaces repeater
    Repeater {
        model: Hyprland.workspaces
        delegate: specialWorkspaceDelegate
    }
}
