import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
  id: activeWindow

  // Icon
  readonly property string appIconSource: resolveIconSource(currentClass)

  // Public state
  property string appName: ""
  property string currentClass: ""
  property string currentTitle: ""
  property string displayText: ""
  property int maxLength: 60

  // ---- Helpers (minimal, no over-guarding) ----
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

  function isRawSource(s) {
    if (!s)
      return false;
    const v = String(s);
    return v.startsWith("file:") || v.startsWith("data:") || v.startsWith("/") || v.startsWith("qrc:");
  }

  function resolveIconSource(key, fallback) {
    const appId = String(key || "");
    // 1) From desktop entry
    const entry = appId ? DesktopEntries.heuristicLookup(appId) || DesktopEntries.byId(appId) : null;
    if (entry && entry.icon)
      return themedOrRaw(entry.icon);

    // 2) Directly from appId as a themed name
    if (appId) {
      const fromAppId = themedOrRaw(appId);
      if (fromAppId)
        return fromAppId;
    }

    // 3) Provided fallback or default
    const fb = fallback ? String(fallback) : "application-x-executable";
    return themedOrRaw(fb);
  }

  function themedOrRaw(nameOrPath) {
    if (!nameOrPath)
      return "";
    const s = String(nameOrPath).trim();
    return isRawSource(s) ? s : "image://icon/" + s;
  }

  function updateActive() {
    const top = ToplevelManager.activeToplevel;
    if (top) {
      activeWindow.currentTitle = top.title || "";
      activeWindow.currentClass = top.appId || "";
      const entry = (activeWindow.currentClass && (DesktopEntries.heuristicLookup(activeWindow.currentClass) || DesktopEntries.byId(activeWindow.currentClass))) || null;
      activeWindow.appName = (entry && entry.name) ? entry.name : (activeWindow.currentClass || "");
    } else {
      activeWindow.currentTitle = "";
      activeWindow.currentClass = "";
      activeWindow.appName = "";
    }
    activeWindow.displayText = activeWindow.computeDisplayText();
  }

  // Layout uses themed metrics
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
    function onTitleChanged() {
      activeWindow.updateActive();
    }

    target: ToplevelManager.activeToplevel
  }

  Row {
    id: titleRow

    anchors.fill: parent
    spacing: 6

    // App icon (simple visibility rule)
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
