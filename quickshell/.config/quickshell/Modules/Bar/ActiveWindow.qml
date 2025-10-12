import QtQuick
import Quickshell.Wayland
import qs.Services.Utils
import qs.Services.WM
import qs.Config

Item {
  id: root

  readonly property string appId: ToplevelManager.activeToplevel?.appId || ""
  property string desktopIconName: "applications-system"
  readonly property bool hasActive: {
    const tl = ToplevelManager.activeToplevel;
    const ws = WorkspaceService.workspaces.find(w => w.id === WorkspaceService.currentWorkspace);
    return !!(tl?.activated && (tl.appId || tl.title) && (ws?.populated || WorkspaceService.activeSpecial));
  }
  property int maxLength: 47
  readonly property string text: {
    if (!hasActive)
      return "Desktop";
    const name = Utils.resolveDesktopEntry(appId)?.name || appId;
    const display = name === "Zen Browser" ? title : !title ? (name || "Desktop") : !name ? title : `${name}: ${title}`;
    return display.length > maxLength ? display.slice(0, maxLength - 3) + "..." : display;
  }
  readonly property string title: ToplevelManager.activeToplevel?.title || ""

  implicitHeight: row.implicitHeight
  implicitWidth: row.implicitWidth

  Behavior on implicitWidth {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  Row {
    id: row

    spacing: 6

    Image {
      fillMode: Image.PreserveAspectFit
      height: 28
      source: root.hasActive ? Utils.resolveIconSource(root.appId) : Utils.resolveIconSource("", "", root.desktopIconName)
      sourceSize: Qt.size(width, height)
      visible: !!source
      width: 28
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      color: Theme.textContrast(Theme.bgColor)
      text: root.text

      font {
        bold: true
        family: Theme.fontFamily
        pixelSize: Theme.fontSize
      }
    }
  }
}
