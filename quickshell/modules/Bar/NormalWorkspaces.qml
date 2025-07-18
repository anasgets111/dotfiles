import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Item {
    id: root
        property bool expanded: false
        property int hoveredIndex: 0

        function workspaceColor(ws) {
            var c
            if (ws.active)         c = Theme.activeColor
            else if (ws.id === hoveredIndex) c = Theme.onHoverColor
            else if (ws.populated) c = Theme.inactiveColor
            else                    c = Theme.disabledColor
            return c
        }

        property var workspaceStatusList: (function(){
            var arr   = Hyprland.workspaces.values
            var wsMap = arr.reduce((m,w)=>(m[w.id]=w,m),{})
            return Array.from({length:10},(_,i)=>{
                var w = wsMap[i+1]
                return {
                    id:        i+1,
                    active:    !!(w && w.active),
                    populated: !!w
                }
            })
        })()

        Timer {
            id: collapseTimer
            interval: Theme.animationDuration + 200
            onTriggered: {
                expanded = false
                hoveredIndex = 0
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor

            onEntered: {
                expanded = true
                collapseTimer.stop()
            }
            onExited: {
                collapseTimer.restart()
            }
            onPositionChanged: {
                var sp = expanded ? workspacesRow.spacing : 0
                var cell = Theme.itemWidth + sp
                var idx = Math.floor(mouse.x / cell) + 1
                if (idx >= 1 && idx <= workspaceStatusList.length) {
                    hoveredIndex = idx
                } else {
                    hoveredIndex = 0
                }
            }
            onClicked: {
                if (hoveredIndex > 0) {
                    Hyprland.dispatch("workspace " + hoveredIndex)
                }
            }
        }

        Row {
            id: workspacesRow
            spacing: expanded ? 8 : 0

            Repeater {
                model: workspaceStatusList
                delegate: Rectangle {
                    property var ws: modelData
                    width:  (ws.active || expanded)
                            ? Theme.itemWidth
                            : 0
                    height: Theme.itemHeight
                    radius: Theme.itemRadius

                    color:   workspaceColor(ws)
                    opacity: (ws.active || expanded)
                             ? (ws.populated ? 1.0 : 0.5)
                             : 0.0

                    Behavior on width {
                        NumberAnimation {
                            duration:    Theme.animationDuration
                            easing.type: Easing.InOutQuad
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration:    Theme.animationDuration
                            easing.type: Easing.InOutQuad
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration:    Theme.animationDuration
                            easing.type: Easing.InOutQuart
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text:            ws.id
                        color:           Theme.textContrast(parent.color)
                        Behavior on color {
                            ColorAnimation {
                                duration:    Theme.animationDuration
                                easing.type:  Easing.InOutQuad
                            }
                        }
                        font.pixelSize:  Theme.fontSize
                        font.family:     Theme.fontFamily
                        font.bold:       true
                    }
                }
            }
        }

        Text {
            visible: !workspaceStatusList.some(ws => ws.populated)
            text:    "No workspaces"
            color:   Theme.textContrast(Theme.bgColor)
            font.pixelSize: Theme.fontSize
            font.family:    Theme.fontFamily
            font.bold:      true
        }

        width:  workspacesRow.width
        height: workspacesRow.height
    }
