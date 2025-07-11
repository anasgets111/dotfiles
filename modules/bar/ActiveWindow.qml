import QtQuick
import Quickshell.Hyprland

Item {
    id: activeWindow
    width: windowTitle.implicitWidth
    height: windowTitle.implicitHeight

    // Shared styling properties (inherited from parent)
    property string fontFamily: parent.fontFamily || "CaskaydiaCove Nerd Font Propo"
    property color textActiveColor: parent.textActiveColor || "#ffffff"
    property color textInactiveColor: parent.textInactiveColor || "#cccccc"
    property int animationDuration: parent.animationDuration || 250
    property int fontSize: parent.fontSize || 12

    // Debug fontSize
    Component.onCompleted: {
        console.log("ActiveWindow fontSize:", fontSize)
        console.log("ActiveWindow parent fontSize:", parent.fontSize)
    }

    // Window state
    property string currentTitle: ""
    property string currentClass: ""

    // Track active window changes via raw events
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindow") {
                // Parse event data: "class,title"
                var data = event.data.split(",")
                if (data.length >= 2) {
                    activeWindow.currentClass = data[0] || ""
                    activeWindow.currentTitle = data[1] || ""
                } else if (data.length === 1 && data[0] === "") {
                    // No active window (desktop)
                    activeWindow.currentClass = ""
                    activeWindow.currentTitle = ""
                } else if (data.length === 1) {
                    // Only class available
                    activeWindow.currentClass = data[0] || ""
                    activeWindow.currentTitle = ""
                }
            }
        }
    }

    // Smooth width animation
    Behavior on width {
        NumberAnimation { duration: animationDuration; easing.type: Easing.InOutQuad }
    }

    Text {
        id: windowTitle
        text: {
            if (activeWindow.currentTitle) {
                // Limit title length to prevent excessive width
                var title = activeWindow.currentTitle
                return title.length > 74 ? title.substring(0, 71) + "..." : title
            } else if (activeWindow.currentClass) {
                return activeWindow.currentClass
            } else {
                return "Desktop"
            }
        }
        color: activeWindow.currentTitle ? textActiveColor : textInactiveColor
        font.pixelSize: fontSize
        font.family: fontFamily
        elide: Text.ElideRight

        // Smooth color transition
        Behavior on color {
            ColorAnimation { duration: animationDuration; easing.type: Easing.InOutQuad }
        }
    }
}
