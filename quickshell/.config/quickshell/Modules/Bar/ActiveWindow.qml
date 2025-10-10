import QtQuick
import Quickshell.Wayland
import qs.Services.Utils
import qs.Services.WM
import qs.Config

Item {
  id: root

  property string desktopIconName: "applications-system"
  property int maxLength: 47

  // Derive everything directly from ToplevelManager.activeToplevel without storing reference
  readonly property string appId: ToplevelManager.activeToplevel?.appId || ""
  readonly property string title: ToplevelManager.activeToplevel?.title || ""

  readonly property bool hasActive: (() => {
      const tl = ToplevelManager.activeToplevel;
      return !!(tl?.activated && tl?.screens?.length && (tl.appId || tl.title) && (WorkspaceService.workspaces.find(w => w.id === WorkspaceService.currentWorkspace)?.populated || WorkspaceService.activeSpecial));
    })()

  readonly property string appName: hasActive ? (Utils.resolveDesktopEntry(appId)?.name || appId) : ""
  readonly property string displayText: !hasActive ? "Desktop" : !title ? (appName || "Desktop") : !appName ? title : (appName === "Zen Browser" ? title : appName + ": " + title)
  readonly property string text: displayText.length > maxLength ? displayText.substring(0, maxLength - 3) + "..." : displayText

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
      source: {
        const id = ToplevelManager.activeToplevel?.appId || "";
        return root.hasActive ? Utils.resolveIconSource(id) : Utils.resolveIconSource("", "", root.desktopIconName);
      }
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
