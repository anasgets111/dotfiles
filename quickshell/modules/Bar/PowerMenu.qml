import QtQuick
import QtQuick.Controls
import Quickshell.Io

Rectangle {
    id: powerMenu

    property int hoverCount: 0
    property bool internalHovered: false
    property bool expanded: internalHovered
    property int spacing: 8
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
        actionProc.command = ["sh", "-c", "pkill chromium 2>/dev/null || true; " + cmd];
        actionProc.running = true;
    }

    width: expanded ? expandedWidth : collapsedWidth
    height: Theme.itemHeight
    radius: Theme.itemRadius
    color: "transparent"
    onHoverCountChanged: {
        if (hoverCount > 0) {
            internalHovered = true;
            collapseTimer.stop();
        } else {
            collapseTimer.restart();
        }
    }

    Process {
        id: actionProc

        running: false
    }

    Timer {
        id: collapseTimer

        interval: Theme.animationDuration
        repeat: false
        onTriggered: {
            if (powerMenu.hoverCount <= 0)
                powerMenu.internalHovered = false;
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: powerMenu.hoverCount++
        onExited: powerMenu.hoverCount--
    }

    Row {
        id: buttonRow

        spacing: 8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: buttons

            delegate: Rectangle {
                id: btnRect

                property int idx: index
                property bool shouldShow: expanded || idx === buttons.length - 1
                property bool isHovered: false

                width: shouldShow ? Theme.itemWidth : 0
                height: Theme.itemHeight
                radius: Theme.itemRadius
                color: isHovered ? Theme.activeColor : Theme.inactiveColor
                visible: opacity > 0 || width > 0
                opacity: shouldShow ? 1 : 0

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: shouldShow
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        isHovered = true;
                        powerMenu.hoverCount++;
                    }
                    onExited: {
                        isHovered = false;
                        powerMenu.hoverCount--;
                    }
                    onClicked: execAction(buttons[idx].action)
                }

                // Tooltip for button
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
                        text: buttons[idx].tooltip
                        color: Theme.textContrast(btnRect.isHovered ? Theme.onHoverColor : Theme.inactiveColor)
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
                    text: buttons[idx].icon
                    color: Theme.textContrast(parent.color)
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

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.InOutQuart
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
