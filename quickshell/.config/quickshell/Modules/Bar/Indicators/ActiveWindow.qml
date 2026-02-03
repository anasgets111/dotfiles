import QtQuick
import Quickshell.Wayland
import qs.Components
import qs.Services.Utils
import qs.Config

Item {
  id: root

  readonly property var activeToplevel: ToplevelManager.activeToplevel
  readonly property string appId: activeToplevel?.appId ?? ""
  readonly property string displayName: Utils.lookupDesktopEntryName(appId) || appId
  readonly property string baseLabel: title || displayName
  readonly property bool hasActive: !!(activeToplevel?.activated && (appId || title))
  readonly property string iconSource: hasActive ? Utils.resolveIconSource(appId) : Utils.resolveIconSource("", "", "applications-system")
  property int maxLength: Theme._isUltrawide ? 74 : 47
  readonly property string text: {
    if (!hasActive)
      return "Desktop";
    return baseLabel.length > maxLength ? `${baseLabel.slice(0, maxLength - 3)}...` : baseLabel;
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

    spacing: Theme.spacingXs

    Image {
      fillMode: Image.PreserveAspectFit
      height: Theme.controlHeightSm
      source: root.iconSource
      sourceSize: Qt.size(width, height)
      visible: !!source
      width: Theme.controlHeightSm
    }

    OText {
      anchors.verticalCenter: parent.verticalCenter
      bold: true
      color: Theme.textContrast(Theme.bgColor)
      text: root.text
    }
  }
}
