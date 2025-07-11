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
            property bool isActive: ws.name
                                    === specialWorkspaces.activeSpecialWorkspace
            // Per-item hover state
            property bool itemHovered: false

            visible: ws.id < 0
            width: Theme.itemWidth
            height: Theme.itemHeight
            radius: Theme.itemRadius
            // Dynamic color: prioritize active, then hover, then inactive
            color: isActive ? Theme.activeColor
                            : (itemHovered ? Theme.onHoverColor
                                           : Theme.inactiveColor)
            opacity: visible ? 1.0 : 0.0

            // Smooth color transitions
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animationDuration
                    easing.type: Easing.InOutQuad
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: parent.itemHovered = true
                onExited: parent.itemHovered = false
                onClicked: Hyprland.dispatch(
                    "togglespecialworkspace " +
                    ws.name.replace("special:", "")
                )
            }

            Text {
                anchors.centerIn: parent
                text: ws.name.replace("special:", "")
                // Dynamic text color matching the background logic: prioritize active, then hover, then inactive
                color: parent.isActive ? Theme.textActiveColor
                                       : (parent.itemHovered
                                          ? Theme.textOnHoverColor
                                          : Theme.textInactiveColor)
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                font.bold: true
                // Smooth text color transition
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.InOutQuad
                    }
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
