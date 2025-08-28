import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
  id: activeWindow

  // Recompute icon when class changes
  readonly property string appIconSource: resolveIconSource(currentClass)

  // ----------------- State -----------------
  property string appName: ""
  property string currentClass: ""
  property string currentTitle: ""
  property string displayText: ""
  property int maxLength: 60

  // ----------------- Helpers -----------------
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
  function resolveIconSource(key) {
    // Very simple, themed-first resolution with a basic fallback
    if (!key)
      return "image://icon/application-x-executable";

    // 1) Desktop entry icon
    try {
      const entry = DesktopEntries.byId(String(key));
      if (entry && entry.icon) {
        return themedOrRaw(entry.icon);
      }
    } catch (e)
    // ignore lookup failure
    {}

    // 2) Use the key itself as an icon name/path
    const byKey = themedOrRaw(key);
    if (byKey)
      return byKey;

    // 3) Fallback
    return "image://icon/application-x-executable";
  }
  function themedOrRaw(nameOrPath) {
    if (!nameOrPath)
      return "";
    const s = String(nameOrPath).trim();
    // accept raw if starts with file:/data:/qrc:/ or absolute path
    if (s.startsWith("file:") || s.startsWith("data:") || s.startsWith("qrc:") || s.startsWith("/")) {
      return s;
    }
    // otherwise, treat as themed icon name
    return "image://icon/" + s;
  }
  function updateActive() {
    var top = ToplevelManager.activeToplevel;
    if (top) {
      activeWindow.currentTitle = top.title || "";
      activeWindow.currentClass = top.appId || "";

      var entry = null;
      try {
        entry = DesktopEntries.byId(activeWindow.currentClass);
      } catch (e) {
        entry = null;
      }
      activeWindow.appName = (entry && entry.name) ? entry.name : activeWindow.currentClass;
    } else {
      activeWindow.currentTitle = "";
      activeWindow.currentClass = "";
      activeWindow.appName = "";
    }
    activeWindow.displayText = activeWindow.computeDisplayText();
  }

  // ----------------- Layout -----------------
  height: titleRow.implicitHeight
  width: titleRow.implicitWidth

  // Keep smooth width animation when title changes
  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  Component.onCompleted: updateActive()

  // React to active toplevel changes
  Connections {
    function onActiveToplevelChanged() {
      activeWindow.updateActive();
    }

    target: ToplevelManager
  }

  // React to title changes on current top-level
  // Note: when activeToplevel changes, the above connection runs;
  // this one will re-bind to the new target automatically in most cases.
  Connections {
    function onAppIdChanged() {
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

    // App icon (simple, themed-first)
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
