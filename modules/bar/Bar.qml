import QtQuick
import Quickshell
import Quickshell.Wayland        // added for Wayland layer-shell support
import Quickshell.Hyprland

PanelWindow {
    id: panel

    screen: Quickshell.screens[0]           // pick output monitor
    mask: Region { item: panelRect }        // mask by Rectangle below
    color: "transparent"                    // make panel area background transparent

    implicitWidth: Screen.width             // span full screen width
    margins {
        left: 16                            // reserve space for workspace icons
        right: 16                           // reserve space for right-side widgets        top: 0                               // no top margin
    }
    implicitHeight: 40                      // set bar height
    exclusiveZone: implicitHeight           // reserve that space in compositor

    WlrLayershell.namespace:                // separate blur layer namespace
        "quickshell:bar:blur"

    anchors {                               // these are layer-shell anchors
        top:   true                         // stick to top edge
        left:  true                         // stick to left edge
        right: true                         // stick to right edge
    }

    Rectangle {
        id: panelRect                       // needed by mask above
        anchors.fill: parent
        color: "#1a1a1a"
        radius: 15
        border.color: "#333333"
        border.width: 3

        property bool normalWorkspacesHovered: false

        Row {
            id: workspaceRow
            anchors {
                left:           parent.left
                leftMargin:     16
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            // Normal workspaces container with hover behavior
            Item {
                id: normalWorkspacesContainer
                width: normalWorkspacesRow.width
                height: normalWorkspacesRow.height

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: panelRect.normalWorkspacesHovered = true
                    onExited: panelRect.normalWorkspacesHovered = false
                }

                Row {
                    id: normalWorkspacesRow
                    spacing: 8

                    // Normal workspaces (positive IDs)
                    Repeater {
                        model: Hyprland.workspaces

                        Rectangle {
                            property bool shouldShow: (modelData.id >= 0) && (modelData.active || panelRect.normalWorkspacesHovered)

                            width: shouldShow ? 32 : 0
                            opacity: shouldShow ? 1.0 : 0.0
                            height: 24
                            radius: 15
                            color: modelData.active ? "#4a9eff" : "#333333"
                            border.color: "#555555"
                            border.width: 2
                            // clip: true

                            Behavior on width {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.InOutQuad
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.InOutQuart
                                }
                            }


                            MouseArea {
                                anchors.fill: parent
                                enabled: shouldShow
                                onClicked: {
                                    Hyprland.dispatch("workspace " + modelData.id);
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.id
                                color: modelData.active ? "#ffffff" : "#cccccc"
                                font.pixelSize: 12
                                font.family: "Inter, sans-serif"
                            }
                        }
                    }
                }
            }

            // Special workspaces (negative IDs)
            Repeater {
                model: Hyprland.workspaces

                Rectangle {
                    visible: modelData.id < 0
                    width: 32
                    height: 24
                    radius: 15
                    color: modelData.active ? "#4a9eff" : "#333333"
                    border.color: "#555555"
                    border.width: 2

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            Hyprland.dispatch("togglespecialworkspace " + modelData.name.replace("special:", ""));
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name.replace("special:", "")
                        color: modelData.active ? "#ffffff" : "#cccccc"
                        font.pixelSize: 12
                        font.family: "Inter, sans-serif"
                    }
                }
            }

            Text {
                visible: Hyprland.workspaces.length === 0
                text:    "No workspaces"
                color:   "#cccccc"
                font.pixelSize: 12
                font.family: "Inter, sans-serif"
            }
        }
    }
}
