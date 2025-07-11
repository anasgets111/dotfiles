import QtQuick
import Quickshell.Hyprland
import "."

Item {

    id: activeWindow
    width: windowTitle.implicitWidth
    height: windowTitle.implicitHeight

    // Styling properties are now accessed from Theme singleton

    // Window state, at init we should check if there is an active window use that otherwise first title will be "Desktop"
    property string currentTitle: ""
    property string currentClass: ""


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
        NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.InOutQuad }
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
        color: activeWindow.currentTitle ? Theme.textActiveColor : Theme.textInactiveColor
        font.pixelSize: Theme.fontSize
        font.weight: Theme.fontWeight
        font.family: Theme.fontFamily
        elide: Text.ElideRight

        // Smooth color transition
        Behavior on color {
            ColorAnimation { duration: Theme.animationDuration; easing.type: Easing.InOutQuad }
        }
    }
}
