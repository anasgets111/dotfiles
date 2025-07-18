import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Item {
    id: root
    property bool expanded: false
    property int hoveredIndex: 0

    // Animation state for collapsed slide
    property int currentWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    property int previousWorkspace: currentWorkspace
    property real slideProgress: 0.0 // 0.0 = previous, 1.0 = current
    property int slideFrom: currentWorkspace
    property int slideTo: currentWorkspace

    // Listen for workspace change events
    Connections {
        target: Hyprland
        onRawEvent: function(event) {
            if (event.name === "workspace") {
                var args = event.parse(2)
                var newId = parseInt(args[0])
                if (newId !== root.currentWorkspace) {
                    root.previousWorkspace = root.currentWorkspace
                    root.currentWorkspace = newId
                    root.slideFrom = root.previousWorkspace
                    root.slideTo = root.currentWorkspace
                    slideAnim.restart()
                }
            }
        }
    }

    NumberAnimation {
        id: slideAnim
        target: root
        property: "slideProgress"
        from: 0.0
        to: 1.0
        duration: Theme.animationDuration
        onStopped: {
            root.slideFrom = root.slideTo
            root.slideProgress = 0.0
        }
    }

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

        // Refined collapsed slide animation (clipped, directional, no overflow)
        Rectangle {
            id: collapsedWs
            visible: !expanded
            width: Theme.itemWidth
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: Theme.bgColor
            opacity: 1.0
            clip: true

            // Direction: -1 for left, 1 for right; default to -1 if no movement
            property int slideDirection: {
                if (slideTo === slideFrom) return -1;
                return slideTo > slideFrom ? -1 : 1;
            }

            // Previous workspace (slides out)
            Rectangle {
                id: prevWsRect
                width: Theme.itemWidth
                height: Theme.itemHeight
                radius: Theme.itemRadius
                color: workspaceColor({id: slideFrom, active: true, populated: true})
                x: slideProgress * collapsedWs.slideDirection * Theme.itemWidth
                visible: slideProgress < 1.0
                Text {
                    anchors.centerIn: parent
                    text: slideFrom
                    color: Theme.textContrast(parent.color)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                    font.bold: true
                }
            }

            Rectangle {
                id: currWsRect
                width: Theme.itemWidth
                height: Theme.itemHeight
                radius: Theme.itemRadius
                color: workspaceColor({id: slideTo, active: true, populated: true})
                x: (slideProgress - 1) * collapsedWs.slideDirection * Theme.itemWidth
                visible: true
                Text {
                    anchors.centerIn: parent
                    text: slideTo
                    color: Theme.textContrast(parent.color)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                    font.bold: true
                }
            }
        }

        Row {
            id: workspacesRow
            visible: expanded
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
