import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool useNiri: true
    property var workspaces: []
    // UI state
    property bool expanded: false
    property int hoveredIndex: 0
    property int currentWorkspace: 1
    property int previousWorkspace: currentWorkspace
    property real slideProgress: 0
    property int slideFrom: currentWorkspace
    property int slideTo: currentWorkspace

    function seedInitial() {
        seedProcWorkspaces.running = true;
    }

    function updateWorkspaces(arr) {
        arr.forEach(function (w) {
            w.populated = w.active_window_id !== null;
        });
        arr.sort(function (a, b) {
            return a.idx - b.idx;
        });
        workspaces = arr;
        var f = arr.find(function (w) {
            return w.is_focused;
        });
        if (f && f.idx !== currentWorkspace) {
            previousWorkspace = currentWorkspace;
            currentWorkspace = f.idx;
            slideFrom = previousWorkspace;
            slideTo = currentWorkspace;
            slideAnim.restart();
        }
    }

    function updateSingleFocus(id) {
        previousWorkspace = currentWorkspace;
        currentWorkspace = id;
        slideFrom = previousWorkspace;
        slideTo = currentWorkspace;
        workspaces.forEach(function (w) {
            w.is_focused = (w.idx === id);
            w.is_active = (w.idx === id);
        });
        workspaces = workspaces;
        slideAnim.restart();
    }

    function workspaceColor(ws) {
        if (ws.is_focused)
            return Theme.activeColor;

        if (ws.idx === hoveredIndex)
            return Theme.onHoverColor;

        if (ws.populated)
            return Theme.inactiveColor;

        return Theme.disabledColor;
    }

    function switchWorkspace(idx) {
        switchProc.running = false;
        switchProc.command = ["niri", "msg", "workspace", String(idx)];
        switchProc.running = true;
    }

    clip: true
    Component.onCompleted: {
        if (useNiri)
            seedInitial();
    }
    width: expanded ? workspacesRow.fullWidth : Theme.itemWidth
    height: Theme.itemHeight

    Process {
        id: seedProcWorkspaces

        command: ["niri", "msg", "--json", "workspaces"]

        stdout: StdioCollector {
            onStreamFinished: {
                var j = JSON.parse(text);
                if (j.Workspaces)
                    root.updateWorkspaces(j.Workspaces.workspaces);
            }
        }
    }

    Process {
        id: eventProcNiri

        running: useNiri
        command: ["niri", "msg", "--json", "event-stream"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (seg) {
                if (!seg)
                    return;

                var evt = JSON.parse(seg);
                if (evt.WorkspacesChanged)
                    root.updateWorkspaces(evt.WorkspacesChanged.workspaces);
                else if (evt.WorkspaceActivated)
                    root.updateSingleFocus(evt.WorkspaceActivated.id);
            }
        }
    }

    Process {
        id: switchProc

        command: ["niri", "msg", "workspace", "1"] // placeholder
    }

    NumberAnimation {
        id: slideAnim

        target: root
        property: "slideProgress"
        from: 0
        to: 1
        duration: Theme.animationDuration
    }

    Timer {
        id: collapseTimer

        interval: Theme.animationDuration + 200
        onTriggered: {
            expanded = false;
            hoveredIndex = 0;
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: {
            expanded = true;
            collapseTimer.stop();
        }
        onExited: collapseTimer.restart()
    }

    Item {
        id: workspacesRow

        property int spacing: 8
        property int count: workspaces.length
        property int fullWidth: count * Theme.itemWidth + Math.max(0, count - 1) * spacing

        visible: expanded
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        width: fullWidth
        height: Theme.itemHeight

        Repeater {
            model: workspaces

            delegate: Rectangle {
                id: wsRect

                property var ws: modelData
                property real slotX: index * (Theme.itemWidth + workspacesRow.spacing)

                width: Theme.itemWidth
                height: Theme.itemHeight
                radius: Theme.itemRadius
                color: workspaceColor(ws)
                opacity: ws.populated ? 1 : 0.5
                x: slotX

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoveredIndex = ws.idx
                    onExited: root.hoveredIndex = 0
                    onClicked: {
                        if (!ws.is_focused)
                            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", ws.idx.toString()]);
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: ws.idx
                    color: Theme.textContrast(parent.color)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    Rectangle {
        id: collapsedWs

        property int slideDirection: slideTo === slideFrom ? -1 : slideTo > slideFrom ? -1 : 1

        visible: !expanded
        z: 1
        width: Theme.itemWidth
        height: Theme.itemHeight
        radius: Theme.itemRadius
        color: Theme.bgColor
        clip: true

        // “from” rect
        Rectangle {
            width: Theme.itemWidth
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: workspaceColor({
                "idx": slideFrom,
                "is_focused": true,
                "populated": true
            })
            x: slideProgress * collapsedWs.slideDirection * Theme.itemWidth
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

        // “to” rect
        Rectangle {
            width: Theme.itemWidth
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: workspaceColor({
                "idx": slideTo,
                "is_focused": true,
                "populated": true
            })
            x: (slideProgress - 1) * collapsedWs.slideDirection * Theme.itemWidth

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

    Text {
        anchors.centerIn: parent
        visible: workspaces.length === 0
        text: "No workspaces"
        color: Theme.textContrast(Theme.bgColor)
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        font.bold: true
    }

    Behavior on width {
        NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
        }
    }
}
