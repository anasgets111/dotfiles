import QtQuick
import Quickshell.Wayland
import qs.Services.Utils
import qs.Config

Item {
  id: activeWindow

  readonly property string appIconSource: activeWindow.hasActive ? Utils.resolveIconSource(activeWindow.currentClass) : Utils.resolveIconSource("", "", activeWindow.desktopIconName)
  property string appName: ""
  property string currentClass: ""
  property string currentTitle: ""

  // Resolve app icon from desktop entry when possible (use Utils default fallback)
  // When there's no active window, show a generic Desktop icon (customizable)
  property string desktopIconName: "applications-system"
  property string displayText: ""
  // True when there is an actually activated toplevel; used to decide Desktop state and icon visibility
  property bool hasActive: false
  property int maxLength: 47
  property bool updating: false

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
    if (activeWindow.updating)
      return;
    activeWindow.updating = true;

    var top = ToplevelManager.activeToplevel;
    // Treat non-activated toplevel as "no active window" (e.g., empty workspace)
    if (top && top.activated) {
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
    activeWindow.hasActive = !!(top && top.activated);

    activeWindow.updating = false;
  }

  height: titleRow.implicitHeight
  width: titleRow.implicitWidth

  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
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
    function onActivatedChanged() {
      activeWindow.updateActive();
    }
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

      anchors.verticalCenter: parent.verticalCenter
      fillMode: Image.PreserveAspectFit
      height: 28
      source: activeWindow.appIconSource
      sourceSize.height: height
      sourceSize.width: width
      // Always show an icon; when Desktop, appIconSource resolves to desktopIconName
      visible: !!source && source !== ""
      width: 28
    }
    Text {
      id: windowTitle

      // centered vertically
      anchors.verticalCenter: parent.verticalCenter
      color: Theme.textContrast(Theme.bgColor)
      elide: Text.ElideRight
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      text: activeWindow.displayText
    }
  }
}
