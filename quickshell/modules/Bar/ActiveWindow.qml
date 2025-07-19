import QtQuick 2.0
import Quickshell.Wayland
import Quickshell

Item {
    id: activeWindow
    width: windowTitle.implicitWidth
    height: windowTitle.implicitHeight

    property int    maxLength: 60
    property string currentTitle: ""
    property string currentClass: ""
    property string appName: ""
    property string displayText: ""

    // Called on any update (new active or title change)
    function updateActive() {
        var top = ToplevelManager.activeToplevel
        if (top) {
            currentTitle = top.title || ""
            currentClass = top.appId || ""
            var entry = DesktopEntries.byId(currentClass)
            appName = entry && entry.name ? entry.name : currentClass
        } else {
            currentTitle = ""
            currentClass = ""
            appName = ""
        }
        displayText = computeDisplayText()
    }

    // Compose + truncate
    function computeDisplayText() {
        var txt
        if (currentTitle && appName) {
            txt = (appName === "Zen Browser")
                ? currentTitle
                : appName + ": " + currentTitle
        } else if (currentTitle) {
            txt = currentTitle
        } else if (appName) {
            txt = appName
        } else {
            txt = "Desktop"
        }
        return txt.length > maxLength
            ? txt.substring(0, maxLength - 3) + "..."
            : txt
    }

    // 1) Active‐window switch
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() { updateActive(); }
    }

    // 2) Title changes on the *current* toplevel
    Connections {
        target: ToplevelManager.activeToplevel
        function onTitleChanged() { updateActive(); }
    }

    Component.onCompleted: updateActive()

    Behavior on width {
        NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
        }
    }

    Text {
        id: windowTitle
        anchors.fill: parent
        text: activeWindow.displayText
        color: Theme.textContrast(Theme.bgColor)
        font.pixelSize: Theme.fontSize
        font.bold: true
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }
}
