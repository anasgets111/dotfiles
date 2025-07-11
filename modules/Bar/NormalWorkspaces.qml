import QtQuick
import Quickshell.Hyprland
import "."

Item {
    id: normalWorkspaces
    width: normalWorkspacesRow.width
    height: normalWorkspacesRow.height

    // State tracking
    property int hoverCount: 0
    property bool internalHovered: false

    // Directly bind for expansion, but delay collapse
    onHoverCountChanged: {
        if (hoverCount > 0) {
            internalHovered = true
            collapseDelayTimer.stop()  // Cancel any pending collapse
        } else {
            collapseDelayTimer.restart()
        }
    }

    // Delayed collapse to prevent jank/sluggishness on quick hover-out/in
    Timer {
        id: collapseDelayTimer
        interval: Theme.animationDuration  // Match animation time to allow smooth completion
        onTriggered: {
            if (normalWorkspaces.hoverCount <= 0) {
                normalWorkspaces.internalHovered = false
            }
        }
    }

    property bool normalWorkspacesHovered: internalHovered

    // Delegate for normal (positive ID) workspaces
    Component {
        id: normalWorkspaceDelegate
        Rectangle {
            property var ws: modelData
            property bool shouldShow: ws.id >= 0
                                      && (ws.active
                                          || normalWorkspaces.normalWorkspacesHovered)
            // Per-item hover state
            property bool itemHovered: false

            width: shouldShow ? Theme.itemWidth : 0
            height: Theme.itemHeight
            radius: Theme.itemRadius
            // Dynamic color: prioritize active, then hover, then inactive
            color: ws.active ? Theme.activeColor
                             : (itemHovered ? Theme.onHoverColor
                                            : Theme.inactiveColor)
            // Always visible while animating; hide only when fully collapsed
            visible: opacity > 0 || width > 0
            opacity: shouldShow ? 1.0 : 0.0

            Behavior on width {
                NumberAnimation {
                    duration: Theme.animationDuration
                    easing.type: Easing.InOutQuad
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animationDuration
                    easing.type: Easing.InOutQuart
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animationDuration
                    easing.type: Easing.InOutQuad
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: shouldShow
                hoverEnabled: true
                onEntered: {
                    parent.itemHovered = true
                    normalWorkspaces.hoverCount++
                }
                onExited: {
                    parent.itemHovered = false
                    normalWorkspaces.hoverCount--
                }
                onClicked: Hyprland.dispatch("workspace " + ws.id)
            }

            Text {
                anchors.centerIn: parent
                text: ws.id
                // Dynamic text color matching the background logic: prioritize active, then hover, then inactive
                color: parent.ws.active ? Theme.textActiveColor
                                        : (parent.itemHovered
                                           ? Theme.textOnHoverColor
                                           : Theme.textInactiveColor)
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
        onEntered: normalWorkspaces.hoverCount++
        onExited: normalWorkspaces.hoverCount--
    }

    // Normal workspaces row
    Row {
        id: normalWorkspacesRow
        spacing: 8  // Consider making this a property for consistency with other modules
        Repeater {
            model: Hyprland.workspaces
            delegate: normalWorkspaceDelegate
        }
    }

    // Fallback when no workspaces
    Text {
        visible: Hyprland.workspaces.length === 0
        text: "No workspaces"
        color: Theme.textInactiveColor
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        font.bold: true
    }
}
