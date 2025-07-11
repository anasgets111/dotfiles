import QtQuick
import Quickshell.Hyprland
import "."

Item {

    id: activeWindow
    width: windowTitle.implicitWidth
    height: windowTitle.implicitHeight

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
        color: Theme.textActiveColor
        font.pixelSize: Theme.fontSize
        font.bold: true
        font.family: Theme.fontFamily
        elide: Text.ElideRight

    }
}
