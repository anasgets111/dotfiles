import QtQuick
import Quickshell.Wayland
import Quickshell

Item {
    id: activeWindow
    width: windowTitle.implicitWidth
    height: windowTitle.implicitHeight

    property int maxLength: 60
    property string currentTitle: ""
    property string currentClass: ""
    property string appName: ""
    property string displayText: ""

    // Called on any update (new active or title change)
    function updateActive() {
        var top = ToplevelManager.activeToplevel;
        if (top) {
            activeWindow.currentTitle = top.title || "";
            activeWindow.currentClass = top.appId || "";
            var entry = DesktopEntries.byId(activeWindow.currentClass);
            activeWindow.appName = entry && entry.name ? entry.name : activeWindow.currentClass;
        } else {
            activeWindow.currentTitle = "";
            activeWindow.currentClass = "";
            activeWindow.appName = "";
        }
        activeWindow.displayText = activeWindow.computeDisplayText();
    }

    // Compose + truncate
    function computeDisplayText() {
        var txt;
        if (activeWindow.currentTitle && activeWindow.appName) {
            txt = (activeWindow.appName === "Zen Browser") ? activeWindow.currentTitle : activeWindow.appName + ": " + activeWindow.currentTitle;
        } else if (activeWindow.currentTitle) {
            txt = activeWindow.currentTitle;
        } else if (activeWindow.appName) {
            txt = activeWindow.appName;
        } else {
            txt = "Desktop";
        }
        return txt.length > activeWindow.maxLength ? txt.substring(0, activeWindow.maxLength - 3) + "..." : txt;
    }

    // 1) Active‐window switch
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            activeWindow.updateActive();
        }
    }

    // 2) Title changes on the *current* toplevel
    Connections {
        target: ToplevelManager.activeToplevel
        function onTitleChanged() {
            activeWindow.updateActive();
        }
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
