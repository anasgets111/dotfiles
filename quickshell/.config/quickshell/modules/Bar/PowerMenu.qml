pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Rectangle {
    id: powerMenu

    property bool internalHovered: false
    property bool expanded: internalHovered
    property int spacing: 8
    property string lastCommand: ""
    property string lastStdout: ""
    property string lastStderr: ""
    property int lastExitCode: 0
    property var buttons: [
        {
            "icon": "󰍃",
            "tooltip": "Log Out",
            "action": "loginctl terminate-user $USER"
        },
        {
            "icon": "",
            "tooltip": "Restart",
            "action": "systemctl reboot"
        },
        {
            "icon": "⏻",
            "tooltip": "Power Off",
            "action": "systemctl poweroff"
        }
    ]
    property int collapsedWidth: Theme.itemWidth
    property int expandedWidth: Theme.itemWidth * buttons.length + spacing * (buttons.length - 1)

    function execAction(cmd) {
        // Run tracked; onExited will post a notify if exit != 0
        powerMenu.lastCommand = cmd; // original command (without pkill)
        powerMenu.lastStdout = "";
        powerMenu.lastStderr = "";
        const fullCmd = `pkill chromium 2>/dev/null || true; ${cmd}`;
        actionProc.command = ["sh", "-c", fullCmd];
        actionProc.running = true;
    }

    width: powerMenu.expanded ? powerMenu.expandedWidth : powerMenu.collapsedWidth
    height: Theme.itemHeight
    radius: Theme.itemRadius
    color: "transparent"

    Process {
        id: actionProc

        running: false
        stdout: StdioCollector {
            onStreamFinished: powerMenu.lastStdout = this.text
        }
        stderr: StdioCollector {
            onStreamFinished: powerMenu.lastStderr = this.text
        }
    }

    Connections {
        target: actionProc
        function onExited(exitCode, exitStatus) {
            powerMenu.lastExitCode = exitCode;
            if (exitCode !== 0)
                notifyDelay.restart();
        }
    }

    // Notify process (separate, simple client of notify-send)
    Process {
        id: notifyProc
        running: false
        // command assigned on demand
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    // Delay a tick to let collectors finish before composing the message
    Timer {
        id: notifyDelay
        interval: 10
        repeat: false
        onTriggered: {
            const summary = "Power action failed";
            const bodyParts = [];
            if (powerMenu.lastStderr && powerMenu.lastStderr.trim().length > 0)
                bodyParts.push(powerMenu.lastStderr.trim());
            else if (powerMenu.lastStdout && powerMenu.lastStdout.trim().length > 0)
                bodyParts.push(powerMenu.lastStdout.trim());
            bodyParts.push(`\nCommand: ${powerMenu.lastCommand}`);
            bodyParts.push(`Exit: ${powerMenu.lastExitCode}`);
            const body = bodyParts.join("\n\n");
            notifyProc.command = ["notify-send", "-u", "critical", summary, body];
            notifyProc.running = true;
        }
    }

    Timer {
        id: collapseTimer

        interval: Theme.animationDuration
        repeat: false
        onTriggered: {
            if (!hoverHandler.hovered)
                powerMenu.internalHovered = false;
        }
    }

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: {
            if (hovered) {
                powerMenu.internalHovered = true;
                collapseTimer.stop();
            } else {
                collapseTimer.restart();
            }
        }
    }

    Row {
        id: buttonRow

        spacing: powerMenu.spacing
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: powerMenu.buttons

            delegate: Rectangle {
                id: btnRect
                required property int index
                property int idx: btnRect.index
                property bool shouldShow: powerMenu.expanded || btnRect.idx === powerMenu.buttons.length - 1
                property bool isHovered: false

                width: btnRect.shouldShow ? Theme.itemWidth : 0
                height: Theme.itemHeight
                radius: Theme.itemRadius
                color: btnRect.isHovered ? Theme.activeColor : Theme.inactiveColor
                visible: opacity > 0 || width > 0
                opacity: btnRect.shouldShow ? 1 : 0

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: btnRect.shouldShow
                    cursorShape: Qt.PointingHandCursor
                    onEntered: btnRect.isHovered = true
                    onExited: btnRect.isHovered = false
                    onClicked: powerMenu.execAction(powerMenu.buttons[btnRect.idx].action)
                }

                Rectangle {
                    id: tooltip

                    visible: btnRect.isHovered
                    color: Theme.onHoverColor
                    radius: Theme.itemRadius
                    width: tooltipText.implicitWidth + 16
                    height: tooltipText.implicitHeight + 8
                    anchors.top: parent.bottom
                    anchors.left: parent.left
                    anchors.topMargin: 8
                    opacity: btnRect.isHovered ? 1 : 0

                    Text {
                        id: tooltipText

                        anchors.centerIn: parent
                        text: powerMenu.buttons[btnRect.idx].tooltip
                        color: Theme.textContrast(tooltip.color)
                        font.pixelSize: Theme.fontSize
                        font.family: Theme.fontFamily
                        font.bold: true
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animationDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: powerMenu.buttons[btnRect.idx].icon
                    color: Theme.textContrast(parent.color)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                focus: false
                Keys.onPressed: event => {
                    if (!btnRect.shouldShow)
                        return;
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        powerMenu.execAction(powerMenu.buttons[btnRect.idx].action);
                        event.accepted = true;
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.InOutQuad
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.InOutQuad
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
    }

    Behavior on width {
        NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
        }
    }
}
