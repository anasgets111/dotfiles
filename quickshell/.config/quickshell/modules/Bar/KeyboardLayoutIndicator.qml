import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: keyboardLayoutIndicator

    readonly property bool useHypr: DetectEnv.isHyprland
    readonly property bool useNiri: DetectEnv.isNiri
    property var layouts: []
    property string currentLayout: ""
    property bool available: false

    function shortName(full) {
        if (!full)
            return "";

        var lang = full.trim().split(" ")[0];
        return lang.slice(0, 2).toUpperCase();
    }

    function update(namesArr, idxOrActive) {
        var names = namesArr.map(function (n) {
            return n.trim();
        });
        keyboardLayoutIndicator.layouts = names;
        keyboardLayoutIndicator.available = names.length > 1;
        if (keyboardLayoutIndicator.useHypr)
            keyboardLayoutIndicator.currentLayout = idxOrActive.trim();
        else
            keyboardLayoutIndicator.currentLayout = names[idxOrActive] || "";
    }

    function seedInitial() {
        if (keyboardLayoutIndicator.useHypr)
            seedProcHypr.running = true;
        else if (keyboardLayoutIndicator.useNiri)
            seedProcNiri.running = true;
    }

    implicitHeight: Theme.itemHeight
    implicitWidth: Math.max(Theme.itemWidth, label.implicitWidth + 12)
    Component.onCompleted: keyboardLayoutIndicator.seedInitial()
    visible: keyboardLayoutIndicator.available

    Process {
        id: seedProcHypr

        running: keyboardLayoutIndicator.useHypr
        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!keyboardLayoutIndicator.useHypr)
                    return;

                var j = JSON.parse(text);
                var arr = [], active = "";
                j.keyboards.forEach(function (k) {
                    if (!k.main)
                        return;

                    k.layout.split(",").forEach(function (l) {
                        var t = l.trim();
                        if (arr.indexOf(t) === -1)
                            arr.push(t);
                    });
                    active = k.active_keymap;
                });
                keyboardLayoutIndicator.update(arr, active);
            }
        }
    }

    Process {
        id: seedProcNiri

        command: ["niri", "msg", "--json", "keyboard-layouts"]

        stdout: StdioCollector {
            onStreamFinished: {
                var j = JSON.parse(text);
                keyboardLayoutIndicator.update(j.names, j.current_idx);
            }
        }
    }

    Connections {
        function onRawEvent(event) {
            if (!keyboardLayoutIndicator.useHypr)
                return;

            if (event.name !== "activelayout")
                return;

            var parts = event.data.split(",");
            keyboardLayoutIndicator.update(parts, parts[parts.length - 1]);
        }

        target: keyboardLayoutIndicator.useHypr ? Hyprland : null
        enabled: keyboardLayoutIndicator.useHypr
    }

    Process {
        id: eventProcNiri

        running: keyboardLayoutIndicator.useNiri
        command: ["niri", "msg", "--json", "event-stream"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (segment) {
                if (!segment)
                    return;

                var evt = JSON.parse(segment);
                if (evt.KeyboardLayoutsChanged) {
                    var kli = evt.KeyboardLayoutsChanged.keyboard_layouts;
                    keyboardLayoutIndicator.update(kli.names, kli.current_idx);
                } else if (evt.KeyboardLayoutSwitched) {
                    var idx = evt.KeyboardLayoutSwitched.idx;
                    if (!keyboardLayoutIndicator.layouts.length)
                        keyboardLayoutIndicator.seedInitial();
                    else
                        keyboardLayoutIndicator.currentLayout = keyboardLayoutIndicator.layouts[idx] || "";
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.itemRadius
        color: Theme.inactiveColor
        implicitWidth: Math.max(Theme.itemWidth, label.implicitWidth + 12)

        RowLayout {
            anchors.fill: parent

            Text {
                id: label

                text: keyboardLayoutIndicator.shortName(keyboardLayoutIndicator.currentLayout)
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                font.bold: true
                color: Theme.textContrast(Theme.inactiveColor)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            }
        }
    }
}
