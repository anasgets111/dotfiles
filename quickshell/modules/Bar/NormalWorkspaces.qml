import QtQuick
import Quickshell.Hyprland

Item {
    id: root
    clip: true                       // ← clip children when width shrinks
    radius: Theme.itemRadius
    property bool expanded: false
    property int hoveredIndex: 0

    // slide‐state for workspace switches
    property int currentWorkspace:
        Hyprland.focusedWorkspace
            ? Hyprland.focusedWorkspace.id
            : 1
    property int previousWorkspace: currentWorkspace
    property real slideProgress: 0.0
    property int slideFrom: currentWorkspace
    property int slideTo: currentWorkspace

    // build a static 1…10 status list once
    property var workspaceStatusList: (function() {
        var arr = Hyprland.workspaces.values
        var map = arr.reduce(function(m, w) {
            m[w.id] = w; return m
        }, {})
        return Array.from({ length: 10 }, function(_, i) {
            var w = map[i+1]
            return {
                id:        i+1,
                active:    !!(w && w.active),
                populated: !!w
            }
        })
    })()

    function workspaceColor(ws) {
        if (ws.active)              return Theme.activeColor
        if (ws.id === hoveredIndex) return Theme.onHoverColor
        if (ws.populated)           return Theme.inactiveColor
                                     return Theme.disabledColor
    }

    // ───── size & expand/collapse animation ─────
    width: expanded
           ? workspacesRow.width
           : Theme.itemWidth
    Behavior on width {
        NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
        }
    }
    height: Theme.itemHeight

    // ───── Hyprland event hookup ─────
    Connections {
        target: Hyprland
        function onRawEvent(evt) {
            if (evt.name === "workspace") {
                var args   = evt.parse(2)
                var newId  = parseInt(args[0])
                if (newId !== currentWorkspace) {
                    previousWorkspace = currentWorkspace
                    currentWorkspace  = newId
                    slideFrom         = previousWorkspace
                    slideTo           = currentWorkspace
                    slideAnim.restart()
                }
            }
        }
    }
    NumberAnimation {
        id: slideAnim
        target: root
        property: "slideProgress"
        from: 0.0; to: 1.0
        duration: Theme.animationDuration
    }

    // ───── hover & click logic ─────
    Timer {
        id: collapseTimer
        interval: Theme.animationDuration + 200
        onTriggered: {
            expanded     = false
            hoveredIndex = 0
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor

        onEntered: {
            expanded = true
            collapseTimer.stop()
        }
        onExited: collapseTimer.restart()
        onPositionChanged: function(mouse) {
            var sp  = expanded
                      ? Theme.itemWidth + 8
                      : Theme.itemWidth
            var idx = Math.floor(mouse.x / sp) + 1
            hoveredIndex = (idx >= 1 && idx <= workspaceStatusList.length)
                           ? idx
                           : 0
        }
        onClicked: {
            if (hoveredIndex > 0)
                Hyprland.dispatch("workspace " + hoveredIndex)
        }
    }

    // ───── the full 1…10 grid, always present behind ─────
    Row {
        id: workspacesRow
        spacing: 8

        Repeater {
            model: workspaceStatusList
            delegate: Rectangle {
                property var ws: modelData
                width:  Theme.itemWidth
                height: Theme.itemHeight
                radius: Theme.itemRadius
                color:  workspaceColor(ws)

                Text {
                    anchors.centerIn: parent
                    text: ws.id
                    color: Theme.textContrast(parent.color)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                    font.bold: true
                }
            }
        }
    }

    // ───── single‐item switcher on top, only when collapsed ─────
    Rectangle {
        id: collapsedWs
        visible: !expanded             // ← hide when we’re expanded!
        z: 1
        width:  Theme.itemWidth
        height: Theme.itemHeight
        radius: Theme.itemRadius
        color:  Theme.bgColor
        clip:   true

        property int slideDirection:
            slideTo > slideFrom ? -1 : 1

        // “from” workspace
        Rectangle {
            width:  Theme.itemWidth
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: workspaceColor({
                id:        slideFrom,
                active:    true,
                populated: true
            })
            x: slideProgress
               * collapsedWs.slideDirection
               * Theme.itemWidth
            visible: slideProgress < 1

            Text {
                anchors.centerIn: parent
                text: slideFrom
                color: Theme.textContrast(parent.color)
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                font.bold: true
            }
        }

        // “to” workspace
        Rectangle {
            width:  Theme.itemWidth
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: workspaceColor({
                id:        slideTo,
                active:    true,
                populated: true
            })
            x: (slideProgress - 1)
               * collapsedWs.slideDirection
               * Theme.itemWidth

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

    // ───── fallback if no workspaces exist ─────
    Text {
        anchors.centerIn: parent
        visible: !workspaceStatusList.some(function(ws) {
            return ws.populated
        })
        text: "No workspaces"
        color: Theme.textContrast(Theme.bgColor)
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        font.bold: true
    }
}
