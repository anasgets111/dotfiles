pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: normalWorkspaces

    property bool expanded: false
    property int hoveredIndex: 0
    property bool isHyprlandSession: ((Quickshell.env && (Quickshell.env("XDG_SESSION_DESKTOP") === "Hyprland" || Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland" || Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))))
    property int currentWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    property int previousWorkspace: currentWorkspace
    property real slideProgress: 0
    property int slideFrom: currentWorkspace
    property int slideTo: currentWorkspace
    property var workspaceStatusList: (function () {
            var arr = Hyprland.workspaces.values;
            var map = arr.reduce(function (m, w) {
                m[w.id] = w;
                return m;
            }, {});
            return Array.from({
                "length": 10
            }, function (_, i) {
                var w = map[i + 1];
                return {
                    "id": i + 1,
                    "focused": !!(w && w.focused),
                    "populated": !!w
                };
            });
        })()

    function workspaceColor(ws) {
        if (ws.focused)
            return Theme.activeColor;

        if (ws.id === normalWorkspaces.hoveredIndex)
            return Theme.onHoverColor;

        if (ws.populated)
            return Theme.inactiveColor;

        return Theme.disabledColor;
    }

    clip: true
    visible: normalWorkspaces.isHyprlandSession
    width: normalWorkspaces.expanded ? workspacesRow.fullWidth : Theme.itemWidth
    height: Theme.itemHeight

    Connections {
        function onRawEvent(evt) {
            if (evt.name === "workspace") {
                var args = evt.parse(2);
                var newId = parseInt(args[0]);
                if (newId !== normalWorkspaces.currentWorkspace) {
                    normalWorkspaces.previousWorkspace = normalWorkspaces.currentWorkspace;
                    normalWorkspaces.currentWorkspace = newId;
                    normalWorkspaces.slideFrom = normalWorkspaces.previousWorkspace;
                    normalWorkspaces.slideTo = normalWorkspaces.currentWorkspace;
                    slideAnim.restart();
                }
            }
        }

        target: Hyprland
    }

    NumberAnimation {
        id: slideAnim

        target: normalWorkspaces
        property: "slideProgress"
        from: 0
        to: 1
        duration: Theme.animationDuration
    }

    Timer {
        id: collapseTimer

        interval: Theme.animationDuration + 200
        onTriggered: {
            normalWorkspaces.expanded = false;
            normalWorkspaces.hoveredIndex = 0;
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            normalWorkspaces.expanded = true;
            collapseTimer.stop();
        }
        onExited: collapseTimer.restart()
        onPositionChanged: function (mouse) {
            var sp = normalWorkspaces.expanded ? Theme.itemWidth + 8 : Theme.itemWidth;
            var idx = Math.floor(mouse.x / sp) + 1;
            normalWorkspaces.hoveredIndex = (idx >= 1 && idx <= normalWorkspaces.workspaceStatusList.length) ? idx : 0;
        }
        onClicked: {
            if (normalWorkspaces.hoveredIndex > 0 && !normalWorkspaces.workspaceStatusList[normalWorkspaces.hoveredIndex - 1].focused)
                Hyprland.dispatch("workspace " + normalWorkspaces.hoveredIndex);
        }
    }

    Item {
        id: workspacesRow

        property int spacing: 8
        property int count: normalWorkspaces.workspaceStatusList.length
        property int fullWidth: count * Theme.itemWidth + Math.max(0, count - 1) * spacing

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        width: fullWidth
        height: Theme.itemHeight

        Repeater {
            model: normalWorkspaces.workspaceStatusList

            delegate: Rectangle {
                id: wsRect
                required property int index
                required property var modelData
                property var ws: wsRect.modelData
                property real slotX: wsRect.index * (Theme.itemWidth + workspacesRow.spacing)

                width: Theme.itemWidth
                height: Theme.itemHeight
                radius: Theme.itemRadius
                color: normalWorkspaces.workspaceColor(wsRect.ws)
                opacity: wsRect.ws.populated ? 1 : 0.5
                x: normalWorkspaces.expanded ? wsRect.slotX : 0

                Text {
                    anchors.centerIn: parent
                    text: wsRect.ws.id
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

        property int slideDirection: normalWorkspaces.slideTo === normalWorkspaces.slideFrom ? -1 : normalWorkspaces.slideTo > normalWorkspaces.slideFrom ? -1 : 1

        visible: !normalWorkspaces.expanded
        z: 1
        width: Theme.itemWidth
        height: Theme.itemHeight
        radius: Theme.itemRadius
        color: Theme.bgColor
        clip: true

        Rectangle {
            width: Theme.itemWidth
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: normalWorkspaces.workspaceColor({
                "id": normalWorkspaces.slideFrom,
                "focused": true,
                "populated": true
            })
            x: normalWorkspaces.slideProgress * collapsedWs.slideDirection * Theme.itemWidth
            visible: normalWorkspaces.slideProgress < 1

            Text {
                anchors.centerIn: parent
                text: normalWorkspaces.slideFrom
                color: Theme.textContrast(parent.color)
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                font.bold: true
            }
        }

        Rectangle {
            width: Theme.itemWidth
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: normalWorkspaces.workspaceColor({
                "id": normalWorkspaces.slideTo,
                "focused": true,
                "populated": true
            })
            x: (normalWorkspaces.slideProgress - 1) * collapsedWs.slideDirection * Theme.itemWidth

            Text {
                anchors.centerIn: parent
                text: normalWorkspaces.slideTo
                color: Theme.textContrast(parent.color)
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                font.bold: true
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !normalWorkspaces.workspaceStatusList.some(function (ws) {
            return ws.populated;
        })
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
