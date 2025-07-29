import QtQuick
import Quickshell.Hyprland

Row {
    id: specialWorkspaces

    property var workspaces: Hyprland.workspaces
    property string activeSpecial: ""
    property var specialWorkspacesList: getSpecialWorkspaces()
    property int maxSpecialWidth: {
        var maxW = Theme.itemWidth;
        for (var i = 0; i < widthProbe.children.length; ++i) {
            var probeW = widthProbe.children[i].implicitWidth + 12;
            if (probeW > maxW)
                maxW = probeW;
        }
        return maxW;
    }

    function getSpecialWorkspaces() {
        var specials = [];
        for (var i = 0; i < workspaces.length; ++i) {
            var ws = workspaces[i];
            if (ws.id < 0)
                specials.push(ws);
        }
        return specials;
    }

    function getSpecialText(ws) {
        var nameLower = ws.name.toLowerCase();
        if (nameLower.includes("telegram"))
            return "\uF2C6";

        if (nameLower.includes("slack"))
            return "\uF3EF";

        if (nameLower.includes("discord") || nameLower.includes("vesktop") || nameLower.includes("string"))
            return "\uF392";

        if (nameLower.includes("term") || nameLower.includes("magic"))
            return "\uF120";

        return ws.name.replace("special:", "");
    }

    spacing: 8

    Column {
        id: widthProbe

        visible: false

        Repeater {
            model: specialWorkspacesList

            delegate: Text {
                property var ws: modelData

                text: {
                    var nameLower = ws.name.toLowerCase();
                    if (nameLower.includes("telegram"))
                        return "\uF2C6";

                    if (nameLower.includes("slack"))
                        return "\uF3EF";

                    if (nameLower.includes("discord") || nameLower.includes("vesktop") || nameLower.includes("string"))
                        return "\uF392";

                    if (nameLower.includes("term") || nameLower.includes("magic"))
                        return "\uF120";

                    return ws.name.replace("special:", "");
                }
                font.pixelSize: Theme.fontSize
                font.family: (text.length === 1 ? "Nerd Font" : Theme.fontFamily)
                font.bold: true
            }
        }
    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "activespecial") {
                activeSpecial = event.data.split(",")[0];
            } else if (event.name === "workspace") {
                if (parseInt(event.data.split(",")[0]) > 0)
                    activeSpecial = "";
            }
        }

        target: Hyprland
    }

    Component {
        id: specialDelegate

        Rectangle {
            property var ws: modelData
            property int probeIndex: {
                var arr = specialWorkspaces.getSpecialWorkspaces();
                for (var i = 0; i < arr.length; ++i) {
                    if (arr[i].name === ws.name)
                        return i;
                }
                return -1;
            }
            property bool isActive: ws.name === specialWorkspaces.activeSpecial
            property bool isHovered: false

            visible: ws.id < 0
            width: (probeIndex >= 0 && widthProbe.children[probeIndex]) ? widthProbe.children[probeIndex].implicitWidth + 12 : Theme.itemWidth
            height: Theme.itemHeight
            radius: Theme.itemRadius
            color: isActive ? Theme.activeColor : (isHovered ? Theme.onHoverColor : Theme.inactiveColor)

            MouseArea {
                id: mouseArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var n = ws.name.replace("special:", "");
                    Hyprland.dispatch("togglespecialworkspace " + n);
                }
                onEntered: parent.isHovered = true
                onExited: parent.isHovered = false
            }

            Text {
                anchors.centerIn: parent
                text: {
                    var nameLower = ws.name.toLowerCase();
                    if (nameLower.includes("telegram"))
                        return "\uF2C6";

                    if (nameLower.includes("slack"))
                        return "\uF3EF";

                    if (nameLower.includes("discord") || nameLower.includes("vesktop") || nameLower.includes("string"))
                        return "\uF392";

                    if (nameLower.includes("term") || nameLower.includes("magic"))
                        return "\uF120";

                    return ws.name.replace("special:", "");
                }
                font.pixelSize: Theme.fontSize
                font.family: (text.length === 1 ? "Nerd Font" : Theme.fontFamily)
                font.bold: true
                color: Theme.textContrast(isActive ? Theme.activeColor : (parent.isHovered ? Theme.onHoverColor : Theme.inactiveColor))

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animationDuration
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }

    Repeater {
        model: workspaces
        delegate: specialDelegate
    }
}
