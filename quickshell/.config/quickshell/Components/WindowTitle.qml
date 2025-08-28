import QtQuick
import Quickshell.Wayland
import qs.Services.Utils

Item {
  id: activeWindow

  // Resolve app icon from desktop entry when possible (use Utils default fallback)
  readonly property string appIconSource: Utils.resolveIconSource(activeWindow.currentClass)
  property string appName: ""
  property string currentClass: ""
  property string currentTitle: ""
  property string displayText: ""
  property int maxLength: 60

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

  height: titleRow.implicitHeight
  width: titleRow.implicitWidth

  Behavior on width {
    NumberAnimation {
      duration: 300
      easing.type: Easing.InOutQuad
    }
  }

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

      fillMode: Image.PreserveAspectFit
      height: 24
      source: activeWindow.appIconSource
      sourceSize.height: height
      sourceSize.width: width
      visible: !!source && source !== ""
      width: 24
    }

    Text {
      id: windowTitle

      color: "#FFFFFF"
      elide: Text.ElideRight
      font.bold: true
      font.family: "Roboto"
      font.pixelSize: 16
      text: activeWindow.displayText
    }
  }
}
