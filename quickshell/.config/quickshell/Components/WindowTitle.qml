import QtQuick
import Quickshell.Wayland
import qs.Services.Utils

Item {
    id: activeWindow

    property int maxLength: 60
    property string currentTitle: ""
    property string currentClass: ""
    property string appName: ""
    // Resolve app icon from desktop entry when possible
    readonly property string appIconSource: Utils.resolveIconSource(activeWindow.currentClass, "application-default-icon")
    property string displayText: ""

    function updateActive() {
        var top = ToplevelManager.activeToplevel;
        if (top) {
            activeWindow.currentTitle = top.title || "";
            activeWindow.currentClass = top.appId || "";
            var entry = Utils.resolveDesktopEntry(activeWindow.currentClass);
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

    width: titleRow.implicitWidth
    height: titleRow.implicitHeight
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

    Row {
        id: titleRow
        anchors.fill: parent
        spacing: 6
        // App icon (hidden when missing)
        Image {
            id: appIcon
            source: activeWindow.appIconSource
            visible: !!source && source !== ""
            width: 24
            height: 24
            sourceSize.width: width
            sourceSize.height: height
            fillMode: Image.PreserveAspectFit
        }
        Text {
            id: windowTitle
            text: activeWindow.displayText
            color: "#FFFFFF"
            font.pixelSize: 16
            font.bold: true
            font.family: "Roboto"
            elide: Text.ElideRight
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: 300
            easing.type: Easing.InOutQuad
        }
    }
}
