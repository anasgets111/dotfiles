import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland

Rectangle {
    id: powerMenu
    clip: true

    //—— Hover / collapse-delay logic —————————————————————————————
    property int  hoverCount:        0
    property bool internalHovered:   false
    property bool expanded:          internalHovered

    onHoverCountChanged: {
        if (hoverCount > 0) {
            internalHovered = true
            collapseTimer.stop()
        } else {
            collapseTimer.restart()
        }
    }

    Timer {
        id: collapseTimer
        interval: Theme.animationDuration
        repeat: false
        onTriggered: {
            if (powerMenu.hoverCount <= 0)
                powerMenu.internalHovered = false
        }
    }

    //—— Dimensions & styling ————————————————————————————————
    property int spacing: 8
    property var buttons: [
        { icon: "󰍃", tooltip: "Log Out",
          action: "hyprctl dispatch exit" },
        { icon: "", tooltip: "Restart",
          action: "systemctl reboot" },
        { icon: "⏻", tooltip: "Power Off",
          action: "systemctl poweroff" }
    ]
    function execAction(cmd) {
        Hyprland.dispatch(
          "exec pkill chromium 2>/dev/null || true; " + cmd
        )
    }

    property int collapsedWidth: Theme.itemWidth
    property int expandedWidth:
        Theme.itemWidth * buttons.length
        + spacing * (buttons.length - 1)

    width:  expanded ? expandedWidth : collapsedWidth
    height: Theme.itemHeight
    radius: Theme.itemRadius
    color:  "transparent"

    Behavior on width {
        NumberAnimation {
            duration:     Theme.animationDuration
            easing.type:  Easing.InOutQuad
        }
    }

    //—— Catch all enters/exits over the full (shrinking) parent ——
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered:  powerMenu.hoverCount++
        onExited:   powerMenu.hoverCount--
    }

    //—— Button row ————————————————————————————————————————————
    Row {
        id: buttonRow
        spacing:          8
        anchors.right:    parent.right
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: buttons
            delegate: Rectangle {
                id: btnRect
                property int  idx:      index
                property bool shouldShow:
                    expanded || idx === buttons.length - 1
                property bool isHovered: false

                width:   shouldShow ? Theme.itemWidth : 0
                height:  Theme.itemHeight
                radius:  Theme.itemRadius

                color:   isHovered
                         ? Theme.activeColor
                         : Theme.inactiveColor
                visible: opacity > 0 || width > 0
                opacity: shouldShow ? 1.0 : 0.0

                Behavior on width {
                    NumberAnimation {
                        duration:     Theme.animationDuration
                        easing.type:  Easing.InOutQuad
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration:     Theme.animationDuration
                        easing.type:  Easing.InOutQuart
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration:     Theme.animationDuration
                        easing.type:  Easing.InOutQuad
                    }
                }

                MouseArea {
                    anchors.fill:      parent
                    hoverEnabled:      true
                    enabled:           shouldShow
                    cursorShape:       Qt.PointingHandCursor
                    onEntered: {
                        isHovered = true
                        powerMenu.hoverCount++
                    }
                    onExited: {
                        isHovered = false
                        powerMenu.hoverCount--
                    }
                    onClicked: execAction(buttons[idx].action)
                }

                Text {
                    anchors.centerIn: parent
                    text:        buttons[idx].icon
                    color:       Theme.textContrast(parent.color)
                    font.pixelSize: Theme.fontSize + 5
                    font.family: Theme.fontFamily
                    font.bold:   true
                }
            }
        }
    }
}
