import QtQuick
import QtQuick.Controls
import "."

Rectangle {
    id: powerMenu
    property int expandedWidth: Theme.itemWidth * buttons.length + spacing * (buttons.length - 1)
    property int collapsedWidth: Theme.itemWidth
    width: hovered ? expandedWidth : collapsedWidth
    height: Theme.itemHeight
    radius: Theme.itemRadius
    color: 'transparent'
    border.color: Theme.borderColor
    border.width: 0
    Behavior on width {
        NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.InOutQuad }
    }

    // State tracking for hover
    property bool hovered: false

    // Button definitions: icon, tooltip, and action name
    // Reverse order so main button is rightmost
    property var buttons: [
        { icon: "󰍃", tooltip: "Log Out",   action: "Log Out"   },   // nf-fa-sign_out
        { icon: "", tooltip: "Restart",   action: "Restart"   },   // nf-md-restart
        { icon: "⏻", tooltip: "Power Off", action: "Power Off" }    // nf-fa-power_off
    ]
    property int spacing: 8

    // Only show the last button (Power Off) when not hovered
    property int visibleCount: hovered ? buttons.length : 1

    // MouseArea for hover detection
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: powerMenu.hovered = true
        onExited:  powerMenu.hovered = false

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
                // Only show the last button when not hovered, expand leftward on hover
                property bool shouldShow: idx >= (buttons.length - powerMenu.visibleCount)
                width: shouldShow ? Theme.itemWidth : 0
                height: Theme.itemHeight
                radius: Theme.itemRadius
                color: Theme.inactiveColor

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

                // Highlight active (main) button (main is rightmost, always highlighted)
                color: idx === (buttons.length - 1) ? Theme.activeColor : Theme.inactiveColor

                // Button click area
                MouseArea {
                    anchors.fill: parent
                    enabled: shouldShow
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        console.log("PowerMenu action:", buttons[idx].action)
                    }
                }

                // Icon (NerdFont)
                Text {
                    anchors.centerIn: parent
                    text: buttons[idx].icon
                    color: Theme.textInactiveColor
                    font.pixelSize: Theme.fontSize+5
                    font.family: Theme.fontFamily
                    font.weight: Theme.fontWeight
                }

            }
        }
    }
}
