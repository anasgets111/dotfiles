// Tooltip.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config

Item {
  id: tooltip

  property color bgColor: Theme.onHoverColor
  property Component contentComponent: null
  property int edge: Qt.BottomEdge
  property int fadeDuration: Theme.animationDuration
  readonly property color fgColor: Theme.textContrast(bgColor)
  property real hPadding: 8
  property MouseArea hoverSource: null
  property real radius: Theme.itemRadius
  readonly property bool shouldShow: visibleExplicit || (visibleWhenTargetHovered && hoverSource && hoverSource.containsMouse)
  property Item target: null
  property string text: ""
  property real vPadding: 4
  property bool visibleExplicit: false
  property bool visibleWhenTargetHovered: true
  property real yOffset: 8

  height: bg.implicitHeight

  // Let it render only when it should show (via bg opacity)
  visible: bg.opacity > 0

  // Size derived from content
  width: bg.implicitWidth

  // Position robustly relative to current parent using mapToItem
  // If target is null, stay at 0,0
  x: target ? target.mapToItem(parent, 0, 0).x : 0
  y: target ? (edge === Qt.BottomEdge ? target.mapToItem(parent, 0, target.height).y + yOffset : target.mapToItem(parent, 0, 0).y - height - yOffset) : 0

  Rectangle {
    id: bg

    color: tooltip.bgColor
    implicitHeight: contentCol.implicitHeight + 2 * tooltip.vPadding
    implicitWidth: contentCol.implicitWidth + 2 * tooltip.hPadding
    opacity: tooltip.shouldShow ? 1 : 0
    radius: tooltip.radius

    Behavior on opacity {
      NumberAnimation {
        duration: tooltip.fadeDuration
        easing.type: Easing.OutCubic
      }
    }

    ColumnLayout {
      id: contentCol

      anchors.centerIn: parent
      spacing: 4

      Loader {
        id: slotLoader

        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        sourceComponent: tooltip.contentComponent
        visible: status === Loader.Ready
      }
      Text {
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        color: tooltip.fgColor
        elide: Text.ElideNone
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        text: tooltip.text
        verticalAlignment: Text.AlignVCenter
        visible: slotLoader.status !== Loader.Ready && tooltip.text.length > 0
        wrapMode: Text.NoWrap
      }
    }
  }
}
