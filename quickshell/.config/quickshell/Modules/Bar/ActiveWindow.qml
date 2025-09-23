import QtQuick
import Quickshell.Wayland
import qs.Services.Utils
import qs.Config

Item {
  id: activeWindow

  // configurable
  property string desktopIconName: "applications-system"
  property int maxLength: 47

  // live wayland handle (reactive)
  readonly property var activeToplevel: ToplevelManager.activeToplevel
  readonly property bool toplevelVisible: !!(activeToplevel && activeToplevel.screens && activeToplevel.screens.length > 0)
  readonly property bool hasActive: !!(activeToplevel && activeToplevel.activated && toplevelVisible)
  // derived fields from the active toplevel
  readonly property string currentTitle: hasActive ? (activeToplevel.title || "") : ""
  readonly property string currentClass: hasActive ? (activeToplevel.appId || "") : ""

  // resolve app name via desktop entry when present
  readonly property string appName: hasActive ? ((Utils.resolveDesktopEntry(currentClass)?.name) || currentClass) : ""

  // icon: app when active, otherwise desktop fallback
  readonly property string appIconSource: hasActive ? Utils.resolveIconSource(currentClass) : Utils.resolveIconSource("", "", desktopIconName)

  // display text, elided to maxLength; keep Zen Browser special-case
  readonly property string displayText: (function () {
      let txt = "Desktop";
      if (currentTitle && appName)
        txt = (appName === "Zen Browser") ? currentTitle : (appName + ": " + currentTitle);
      else if (currentTitle)
        txt = currentTitle;
      else if (appName)
        txt = appName;
      return txt.length > maxLength ? txt.substring(0, maxLength - 3) + "..." : txt;
    })()

  width: titleRow.implicitWidth
  height: titleRow.implicitHeight

  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  Row {
    id: titleRow
    anchors.fill: parent
    spacing: 6

    Image {
      id: appIcon
      anchors.verticalCenter: parent.verticalCenter
      width: 28
      height: 28
      fillMode: Image.PreserveAspectFit
      source: activeWindow.appIconSource
      sourceSize.width: width
      sourceSize.height: height
      visible: source !== ""
    }

    Text {
      id: windowTitle
      anchors.verticalCenter: parent.verticalCenter
      text: activeWindow.displayText
      color: Theme.textContrast(Theme.bgColor)
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.bold: true
      elide: Text.ElideRight
    }
  }
}
