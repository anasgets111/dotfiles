import QtQuick
import Quickshell.Hyprland

Item {
    id: normalWorkspaces
    property bool expanded: false
    function workspaceColor(ws, itemHovered) {
        if (ws.active)
            return Theme.activeColor
        else if (itemHovered)
            return Theme.onHoverColor
        else if (ws.populated)
            return Theme.inactiveColor
        else
            return Theme.disabledColor
    }
    property var workspaceStatusList: (function() {
         const arr = Hyprland.workspaces.values
         const wsMap = arr.reduce((m, w) => (m[w.id]=w, m), {})
         return Array.from({length:10}, (_, i) => {
             const w = wsMap[i+1]
             return { id: i+1,
                      active:  !!(w && w.active),
                      populated: !!w }
         })
     })()
    width: normalWorkspacesRow.width
    height: normalWorkspacesRow.height

    Timer {
        id: collapseDelayTimer
        interval: Theme.animationDuration
        onTriggered: {
            normalWorkspaces.expanded = false
            console.log("Timer triggered, expanded set to false")
        }
    }

    Component {
        id: normalWorkspaceDelegate
        Rectangle {
            property var ws: modelData
            property bool itemHovered: containsMouse
            width: (ws.active || normalWorkspaces.expanded) ? Theme.itemWidth : 0
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: normalWorkspaces.workspaceColor(ws, itemHovered)
            opacity: (ws.active || normalWorkspaces.expanded)
                ? (ws.populated ? 1.0 : 0.5)
                : 0.0
            Behavior on width {
                NumberAnimation {
                    duration: Theme.animationDuration
                    easing.type: Easing.InOutQuad
                }
            }
            Behavior on color {
                ColorAnimation {
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
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Hyprland.dispatch("workspace " + ws.id)
                    console.log("Workspace clicked, id:", ws.id)
                }
            }
            Text {
                anchors.centerIn: parent
                text: ws.id
                color: Theme.textContrast(normalWorkspaces.workspaceColor(ws, itemHovered))
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
        acceptedButtons: Qt.NoButton
        onEntered: {
            normalWorkspaces.expanded = true
            collapseDelayTimer.stop()
            console.log("Expanded set to true (outer)")
        }
        onExited: {
            collapseDelayTimer.restart()
            console.log("Timer restarted for collapse (outer)")
        }
    }

    Row {
        id: normalWorkspacesRow
        spacing: 8
        Repeater {
            model: normalWorkspaces.workspaceStatusList
            delegate: normalWorkspaceDelegate
        }
    }

    Text {
        visible: !workspaceStatusList.some(ws => ws.populated)
        text: "No workspaces"
        color: Theme.textContrast(Theme.bgColor)
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        font.bold: true
    }

}
