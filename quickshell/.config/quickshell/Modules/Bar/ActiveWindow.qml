import QtQuick
import Quickshell.Wayland
import qs.Services.Utils
import qs.Services.WM
import qs.Config

Item {
  id: root

  property string desktopIconName: "applications-system"
  property int maxLength: 47

  readonly property string appId: ToplevelManager.activeToplevel?.appId || ""
  readonly property string title: ToplevelManager.activeToplevel?.title || ""
  readonly property bool hasActive: (() => {
      const tl = ToplevelManager.activeToplevel;
      return !!(tl?.activated && tl?.screens?.length && (tl.appId || tl.title) && (WorkspaceService.workspaces.find(w => w.id === WorkspaceService.currentWorkspace)?.populated || WorkspaceService.activeSpecial));
    })()

  readonly property string text: {
    if (!hasActive)
      return "Desktop";
    const name = Utils.resolveDesktopEntry(appId)?.name || appId;
    const display = !title ? (name || "Desktop") : !name ? title : name === "Zen Browser" ? title : `${name}: ${title}`;
    return display.length > maxLength ? display.substring(0, maxLength - 3) + "..." : display;
  }

  width: row.implicitWidth
  height: row.implicitHeight

  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  Row {
    id: row
    anchors.fill: parent
    spacing: 6

    Image {
      anchors.verticalCenter: parent.verticalCenter
      width: 28
      height: 28
      fillMode: Image.PreserveAspectFit
      source: root.hasActive ? Utils.resolveIconSource(root.appId) : Utils.resolveIconSource("", "", root.desktopIconName)
      sourceSize: Qt.size(width, height)
      visible: source !== ""
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      color: Theme.textContrast(Theme.bgColor)
      font {
        family: Theme.fontFamily
        pixelSize: Theme.fontSize
        bold: true
      }
    }
  }
}
