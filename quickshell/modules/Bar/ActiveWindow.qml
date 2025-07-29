import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: activeWindow

    property int maxLength: 60
    property string currentTitle: ""
    property string currentClass: ""
    property string appName: ""
    property string displayText: ""

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

    function computeDisplayText() {
        var txt;
        if (activeWindow.currentTitle && activeWindow.appName)
            txt = (activeWindow.appName === "Zen Browser") ? activeWindow.currentTitle : activeWindow.appName + ": " + activeWindow.currentTitle;
        else if (activeWindow.currentTitle)
            txt = activeWindow.currentTitle;
        else if (activeWindow.appName)
            txt = activeWindow.appName;
        else
            txt = "Desktop";
        return txt.length > activeWindow.maxLength ? txt.substring(0, activeWindow.maxLength - 3) + "..." : txt;
    }

    width: windowTitle.implicitWidth
    height: windowTitle.implicitHeight
    Component.onCompleted: updateActive()

    Connections {
        function onActiveToplevelChanged() {
            activeWindow.updateActive();
        }

        target: ToplevelManager
    }

    Connections {
        function onTitleChanged() {
            activeWindow.updateActive();
        }

        target: ToplevelManager.activeToplevel
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

    Behavior on width {
        NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
        }
    }
}
