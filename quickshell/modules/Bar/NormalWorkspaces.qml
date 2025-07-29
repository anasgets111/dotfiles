import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

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

        if (ws.id === hoveredIndex)
            return Theme.onHoverColor;

        if (ws.populated)
            return Theme.inactiveColor;

        return Theme.disabledColor;
    }

    clip: true
    visible: isHyprlandSession
    width: expanded ? workspacesRow.fullWidth : Theme.itemWidth
    height: Theme.itemHeight

    Connections {
        function onRawEvent(evt) {
            if (evt.name === "workspace") {
                var args = evt.parse(2);
                var newId = parseInt(args[0]);
                if (newId !== currentWorkspace) {
                    previousWorkspace = currentWorkspace;
                    currentWorkspace = newId;
                    slideFrom = previousWorkspace;
                    slideTo = currentWorkspace;
                    slideAnim.restart();
                }
            }
        }

        target: Hyprland
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
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            expanded = true;
            collapseTimer.stop();
        }
        onExited: collapseTimer.restart()
        onPositionChanged: function (mouse) {
            var sp = expanded ? Theme.itemWidth + 8 : Theme.itemWidth;
            var idx = Math.floor(mouse.x / sp) + 1;
            hoveredIndex = (idx >= 1 && idx <= workspaceStatusList.length) ? idx : 0;
        }
        onClicked: {
            if (hoveredIndex > 0 && !workspaceStatusList[hoveredIndex - 1].focused)
                Hyprland.dispatch("workspace " + hoveredIndex);
        }
    }

    Item {
        id: workspacesRow

        property int spacing: 8
        property int count: workspaceStatusList.length
        property int fullWidth: count * Theme.itemWidth + Math.max(0, count - 1) * spacing

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        width: fullWidth
        height: Theme.itemHeight

        Repeater {
            model: workspaceStatusList

            delegate: Rectangle {
                id: wsRect

                property var ws: modelData
                property real slotX: index * (Theme.itemWidth + workspacesRow.spacing)

                width: Theme.itemWidth
                height: Theme.itemHeight
                radius: Theme.itemRadius
                color: workspaceColor(ws)
                opacity: ws.populated ? 1 : 0.5
                x: expanded ? slotX : 0

                Text {
                    anchors.centerIn: parent
                    text: ws.id
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

        Rectangle {
            width: Theme.itemWidth
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: workspaceColor({
                "id": slideFrom,
                "focused": true,
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

        Rectangle {
            width: Theme.itemWidth
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: workspaceColor({
                "id": slideTo,
                "focused": true,
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
        visible: !workspaceStatusList.some(function (ws) {
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
