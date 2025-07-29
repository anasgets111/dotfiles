pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var updateCommand: ["xdg-terminal-exec", "--title=Global Updates", "-e", "/home/anas/.config/waybar/update.sh"]
    property bool hovered: false
    property bool popupHovered: false
    property bool busy: false
    property int updates: 0
    property var updatePackages: []
    property string rawOutput: ""
    property double lastSync: 0
    property bool lastWasFull: false
    property int failureCount: 0
    property int failureThreshold: 3
    property int minuteMs: 60 * 1000
    property int pollInterval: 1 * minuteMs
    property int syncInterval: 5 * minuteMs

    function runUpdate() {
        if (busy)
            return;

        if (updates > 0)
            Quickshell.execDetached(updateCommand);
        else
            doPoll(true);
    }

    function notify(urgency, title, body) {
        notifyProc.command = ["notify-send", "-u", urgency, "-A", "update=Update Now", "-w", title, body];
        notifyProc.running = true;
    }

    function startUpdateProcess(cmd) {
        pkgProc.command = cmd;
        pkgProc.running = true;
        killTimer.restart();
    }

    function doPoll(forceFull = false) {
        if (busy)
            return;

        busy = true;
        const now = Date.now();
        const full = forceFull || (now - lastSync > syncInterval);
        lastWasFull = full;
        if (full)
            startUpdateProcess(["checkupdates", "--nocolor"]);
        else
            startUpdateProcess(["checkupdates", "--nosync", "--nocolor"]);
    }

    implicitHeight: Theme.itemHeight
    implicitWidth: Math.max(Theme.itemWidth, indicator.implicitWidth + (updateCount.visible ? updateCount.implicitWidth : 0))
    Component.onCompleted: {
        doPoll();
        pollTimer.start();
    }

    Process {
        id: notifyProc

        onExited: function (exitCode, exitStatus) {
            var act = (notifyOut.text || "").trim();
            if (act === "update")
                root.runUpdate();
        }

        stdout: StdioCollector {
            id: notifyOut
        }
    }

    Process {
        id: pkgProc

        onExited: function (exitCode, exitStatus) {
            const stderrText = (err.text || "").trim();
            if (stderrText)
                console.warn("[UpdateChecker] stderr:", stderrText);

            if (!pkgProc.running && !root.busy)
                return;

            killTimer.stop();
            root.busy = false;
            const raw = (out.text || "").trim();
            root.rawOutput = raw;
            const list = raw ? raw.split(/\r?\n/) : [];
            root.updates = list.length;
            var pkgs = [];
            for (var i = 0; i < list.length; ++i) {
                var m = list[i].match(/^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/);
                if (m)
                    pkgs.push({
                        "name": m[1],
                        "oldVersion": m[2],
                        "newVersion": m[3]
                    });
            }
            root.updatePackages = pkgs;
            if (exitCode !== 0 && exitCode !== 2) {
                root.failureCount++;
                if (root.failureCount >= root.failureThreshold) {
                    root.notify("critical", "Update check failed", "Exit code: " + exitCode + " (failed " + root.failureCount + " times)");
                    root.failureCount = 0;
                }
                root.updates = 0;
                root.updatePackages = [];
                return;
            }
            root.failureCount = 0;
            if (root.updates > 0) {
                const msg = root.updates === 1 ? "One package can be upgraded" : root.updates + " packages can be upgraded";
                root.notify("normal", "Updates Available", msg);
            }
            if (root.lastWasFull)
                root.lastSync = Date.now();
        }

        stdout: StdioCollector {
            id: out
        }

        stderr: StdioCollector {
            id: err
        }
    }

    Timer {
        id: pollTimer

        interval: root.pollInterval
        repeat: true
        onTriggered: root.doPoll()
    }

    Timer {
        id: killTimer

        interval: root.minuteMs
        repeat: false
        onTriggered: {
            if (pkgProc.running) {
                // pkgProc.kill(); // Not available on QML Process
                root.busy = false;
                root.notify("critical", qsTr("Update check killed"), qsTr("Process took too long"));
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.itemRadius
        color: root.hovered && !root.busy ? Theme.onHoverColor : Theme.inactiveColor

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.hovered = true
            onExited: root.hovered = false
            onClicked: {
                if (root.busy)
                    return;

                if (root.updates > 0)
                    Quickshell.execDetached(root.updateCommand);
                else
                    root.doPoll(true);
            }
        }

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: 4

            Text {
                id: indicator

                text: root.busy ? "" : root.updates > 0 ? "" : "󰂪"
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                color: Theme.textContrast(root.hovered && !root.busy ? Theme.onHoverColor : Theme.inactiveColor)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: root.busy
                    onStopped: indicator.rotation = 0
                }
            }

            Text {
                id: updateCount

                visible: root.updates > 0
                text: root.updates
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                color: Theme.textContrast(root.hovered && !root.busy ? Theme.onHoverColor : Theme.inactiveColor)
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Rectangle {
            id: tooltip

            visible: mouseArea.containsMouse && !root.busy
            color: Theme.onHoverColor
            radius: Theme.itemRadius
            width: tooltipText.width + 16
            height: tooltipText.height + 8
            anchors.top: mouseArea.bottom
            anchors.left: mouseArea.left
            anchors.topMargin: 8
            opacity: mouseArea.containsMouse ? 1 : 0

            Column {
                id: tooltipText

                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: root.updates === 0 ? qsTr("No updates available") : root.updates === 1 ? qsTr("One package can be upgraded:") : root.updates + qsTr(" packages can be upgraded:")
                    color: Theme.textContrast(root.hovered && !root.busy ? Theme.onHoverColor : Theme.inactiveColor)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                }

                Repeater {
                    model: root.updatePackages

                    delegate: Text {
                        required property var model
                        text: model.name + ": " + model.oldVersion + " → " + model.newVersion
                        color: Theme.textContrast(root.hovered && !root.busy ? Theme.onHoverColor : Theme.inactiveColor)
                        font.pixelSize: Theme.fontSize
                        font.family: Theme.fontFamily
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animationDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
