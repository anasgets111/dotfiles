import QtQuick
import Quickshell.Hyprland

Item {
    id: normalWorkspaces
    width: normalWorkspacesRow.width
    height: normalWorkspacesRow.height

    property int hoverCount: 0
    property bool internalHovered: false
    property bool normalWorkspacesHovered: internalHovered

    onHoverCountChanged: {
        if (hoverCount > 0) {
            internalHovered = true
            collapseDelayTimer.stop()
        } else {
            collapseDelayTimer.restart()
        }
    }

    Timer {
        id: collapseDelayTimer
        interval: Theme.animationDuration
        onTriggered: {
            if (normalWorkspaces.hoverCount <= 0) {
                normalWorkspaces.internalHovered = false
            }
        }
    }

    Component {
        id: normalWorkspaceDelegate
        Rectangle {
            property var ws: modelData
            property bool shouldShow: ws.id >= 0
                                      && (ws.active
                                          || normalWorkspaces.normalWorkspacesHovered)
            property bool itemHovered: false

            width: shouldShow ? Theme.itemWidth : 0
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: ws.active ? Theme.activeColor
                             : (itemHovered ? Theme.onHoverColor
                                            : Theme.inactiveColor)
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
                enabled: shouldShow && !ws.active
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
                color: Theme.textContrast(
                    parent.ws.active ? Theme.activeColor
                    : (parent.itemHovered ? Theme.onHoverColor : Theme.inactiveColor)
                )
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.InOutQuad
                    }
                }
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                font.bold: true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: normalWorkspaces.hoverCount++
        onExited: normalWorkspaces.hoverCount--
    }

    Row {
        id: normalWorkspacesRow
        spacing: 8
        Repeater {
            model: Hyprland.workspaces
            delegate: normalWorkspaceDelegate
        }
    }

    Text {
        visible: Hyprland.workspaces.length === 0
        text: "No workspaces"
        color: Theme.textContrast(Theme.bgColor)
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        font.bold: true
    }
}
