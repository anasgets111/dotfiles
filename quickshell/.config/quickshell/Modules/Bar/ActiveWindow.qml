import QtQuick
import Quickshell.Wayland
import qs.Services.Utils
import qs.Config

Item {
  id: root

  readonly property var activeToplevel: ToplevelManager.activeToplevel
  readonly property string appId: activeToplevel?.appId ?? ""
  readonly property bool hasActive: !!(activeToplevel?.activated && (appId || title))
  readonly property string iconSource: hasActive ? Utils.resolveIconSource(appId) : Utils.resolveIconSource("", "", "applications-system")
  property int maxLength: 47
  readonly property string text: {
    if (!hasActive)
      return "Desktop";
    const base = title || appId;
    return base.length > maxLength ? `${base.slice(0, maxLength - 3)}...` : base;
  }
  readonly property string title: activeToplevel?.title ?? ""

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
      source: root.iconSource
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
