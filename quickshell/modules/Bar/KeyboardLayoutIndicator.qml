import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    // --- Begin merged KbService logic ---
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
        layouts = names;
        available = names.length > 1;
        if (useHypr)
            currentLayout = idxOrActive.trim();
        else
            currentLayout = names[idxOrActive] || "";
    }

    function seedInitial() {
        if (useHypr)
            seedProcHypr.running = true;
        else if (useNiri)
            seedProcNiri.running = true;
    }

    implicitHeight: Theme.itemHeight
    implicitWidth: Math.max(Theme.itemWidth, label.implicitWidth + 12)
    Component.onCompleted: seedInitial()
    visible: available

    Process {
        id: seedProcHypr

        running: useHypr
        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!useHypr)
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
                root.update(arr, active);
            }
        }
    }

    Process {
        id: seedProcNiri

        command: ["niri", "msg", "--json", "keyboard-layouts"]

        stdout: StdioCollector {
            onStreamFinished: {
                var j = JSON.parse(text);
                root.update(j.names, j.current_idx);
            }
        }
    }

    Connections {
        function onRawEvent(event) {
            if (!useHypr)
                return;

            if (event.name !== "activelayout")
                return;

            var parts = event.data.split(",");
            root.update(parts, parts[parts.length - 1]);
        }

        target: useHypr ? Hyprland : null
        enabled: useHypr
    }

    Process {
        id: eventProcNiri

        running: useNiri
        command: ["niri", "msg", "--json", "event-stream"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (segment) {
                if (!segment)
                    return;

                var evt = JSON.parse(segment);
                if (evt.KeyboardLayoutsChanged) {
                    var kli = evt.KeyboardLayoutsChanged.keyboard_layouts;
                    root.update(kli.names, kli.current_idx);
                } else if (evt.KeyboardLayoutSwitched) {
                    var idx = evt.KeyboardLayoutSwitched.idx;
                    if (!root.layouts.length)
                        root.seedInitial();
                    else
                        root.currentLayout = root.layouts[idx] || "";
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

                text: shortName(currentLayout)
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
