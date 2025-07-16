import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland

Rectangle {
    id: powerMenu
    property int expandedWidth: Theme.itemWidth * buttons.length + spacing * (buttons.length - 1)
    property int collapsedWidth: Theme.itemWidth
    width: hovered ? expandedWidth : collapsedWidth
    height: Theme.itemHeight
    radius: Theme.itemRadius
    color: 'transparent'
    Behavior on width {
        NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.InOutQuad }
    }

    property int hoverCount: 0
    property bool hovered: hoverCount > 0

    property var buttons: [
        { icon: "󰍃", tooltip: "Log Out",   action: "hyprctl dispatch exit" },
        { icon: "", tooltip: "Restart",   action: "systemctl reboot" },
        { icon: "⏻", tooltip: "Power Off", action: "systemctl poweroff" }
    ]
    property int spacing: 8

    function execAction(cmd) {
        Hyprland.dispatch("exec pkill chromium 2>/dev/null || true; " + cmd)
    }

    property int minVisibleIndex: hovered ? 0 : buttons.length - 1

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: powerMenu.hoverCount++
        onExited: powerMenu.hoverCount--
    }

    Row {
        id: buttonRow
        spacing: powerMenu.spacing
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            id: buttonRepeater
            model: buttons.length
            delegate: Rectangle {
                property int idx: index
                property bool shouldShow: idx >= powerMenu.minVisibleIndex
                property bool buttonHovered: false
                property bool actuallyVisible: shouldShow || opacity > 0
                width: shouldShow ? Theme.itemWidth : 0
                height: Theme.itemHeight
                radius: Theme.itemRadius
                color: buttonHovered ? Theme.activeColor : Theme.inactiveColor
                visible: actuallyVisible
                opacity: shouldShow ? 1.0 : 0.0

                anchors.verticalCenter: parent.verticalCenter

                Behavior on width {
                    NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.InOutQuad }
                }
                Behavior on opacity {
                    NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.InOutQuart }
                }
                Behavior on color {
                    ColorAnimation { duration: Theme.animationDuration; easing.type: Easing.InOutQuad }
                }

                onOpacityChanged: {
                    if (!shouldShow && opacity === 0) visible = false
                    if (shouldShow && !visible) visible = true
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: shouldShow
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        parent.buttonHovered = true
                        powerMenu.hoverCount++
                    }
                    onExited: {
                        parent.buttonHovered = false
                        powerMenu.hoverCount--
                    }
                    onClicked: {
                        powerMenu.execAction(buttons[idx].action)
                    }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: buttons[idx].icon
                    color: Theme.textInactiveColor
                    font.pixelSize: Theme.fontSize + 5
                    font.family: Theme.fontFamily
                    font.bold: true
                }
            }
        }
    }
}
