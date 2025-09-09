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
  property int hAlign: Qt.AlignLeft
  property int fadeDuration: Theme.animationDuration
  readonly property color fgColor: Theme.textContrast(bgColor)
  property real hPadding: 8
  property MouseArea hoverSource: null
  readonly property bool shouldShow: visibleExplicit || (visibleWhenTargetHovered && hoverSource && hoverSource.containsMouse)
  property Item target: null
  property string text: ""
  property real cornerRadius: Theme.itemRadius
  property real vPadding: 4
  property bool visibleExplicit: false
  property bool visibleWhenTargetHovered: true
  property real xOffset: 0
  property real yOffset: 8

  height: bg.implicitHeight

  visible: bg.opacity > 0

  width: bg.implicitWidth

  x: {
    if (!target)
      return 0;
    const left = target.mapToItem(parent, 0, 0).x;
    if (hAlign === Qt.AlignLeft)
      return left + xOffset;
    if (hAlign === Qt.AlignRight)
      return left + (target.width - width) + xOffset;
    return left + (target.width - width) / 2 + xOffset;
  }
  y: target ? (edge === Qt.BottomEdge ? target.mapToItem(parent, 0, target.height).y + yOffset : target.mapToItem(parent, 0, 0).y - height - yOffset) : 0

  Rectangle {
    id: bg

    color: tooltip.bgColor
    implicitHeight: contentCol.implicitHeight + 2 * tooltip.vPadding
    implicitWidth: contentCol.implicitWidth + 2 * tooltip.hPadding
    opacity: tooltip.shouldShow ? 1 : 0
    radius: tooltip.cornerRadius

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
