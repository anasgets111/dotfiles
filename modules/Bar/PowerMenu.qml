import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland
import "."

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

    // State tracking for hover
    property bool hovered: false
    property int hoverCount: 0

    Binding {
        target: powerMenu
        property: "hovered"
        value: powerMenu.hoverCount > 0
    }

    // Button definitions: icon, tooltip, action
    // Order: left-to-right display (main Power Off is rightmost)
    property var buttons: [
        { icon: "󰍃", tooltip: "Log Out",   action: "pkill chromium 2>/dev/null || true; hyprctl dispatch exit" },
        { icon: "", tooltip: "Restart",   action: "pkill chromium 2>/dev/null || true; systemctl reboot" },
        { icon: "⏻", tooltip: "Power Off", action: "pkill chromium 2>/dev/null || true; systemctl poweroff" }
    ]
    property int spacing: 8

    // Precompute min visible index for efficiency
    property int minVisibleIndex: hovered ? 0 : buttons.length - 1

    // MouseArea for hover detection (menu-level expansion)
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: powerMenu.hoverCount++
        onExited: powerMenu.hoverCount--
    }

    // Animated buttons inside a Row for layout, right-aligned
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
                // Show if index >= minVisibleIndex (expands leftward on hover)
                property bool shouldShow: idx >= powerMenu.minVisibleIndex
                // Per-button hover state
                property bool buttonHovered: false
                width: shouldShow ? Theme.itemWidth : 0
                height: Theme.itemHeight
                radius: Theme.itemRadius
                // Dynamic color: active on button hover, inactive otherwise
                color: buttonHovered ? Theme.activeColor : Theme.inactiveColor
                visible: shouldShow  // Use visible for layout efficiency
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

                // Button click and hover area
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
                        Hyprland.dispatch("exec " + buttons[idx].action)
                        // @idea If you have a global state for menu open, you can close it here:
                        // GlobalStates.hyprMenuOpen = false
                    }
                }

                // Icon (NerdFont)
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
