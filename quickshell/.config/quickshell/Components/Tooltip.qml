// Tooltip.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import qs.Config

Item {
  id: tooltip

  // Inputs
  property color bgColor: Theme.onHoverColor
  property Component contentComponent: null
  property int edge: Qt.BottomEdge
  property int hAlign: Qt.AlignLeft
  property int fadeDuration: Theme.animationDuration
  property real hPadding: 8
  property MouseArea hoverSource: null
  property Item target: null
  property string text: ""
  property real cornerRadius: Theme.itemRadius
  property real vPadding: 4
  property bool visibleExplicit: false
  property bool visibleWhenTargetHovered: true
  property real xOffset: 0
  property real yOffset: 8
  property bool preferBelow: true
  property Item boundsItem: Window.window ? Window.window.contentItem : parent

  // Derived
  readonly property color fgColor: Theme.textContrast(bgColor)
  readonly property bool shouldShow: visibleExplicit || (visibleWhenTargetHovered && hoverSource && hoverSource.containsMouse)
  readonly property real popupWidth: backgroundRect.implicitWidth
  readonly property real popupHeight: backgroundRect.implicitHeight

  readonly property point targetTopLeftInBounds: target && boundsItem ? target.mapToItem(boundsItem, 0, 0) : Qt.point(0, 0)
  readonly property real targetBottomInBounds: target && boundsItem ? target.mapToItem(boundsItem, 0, target.height).y : 0

  // Shared edge resolution
  readonly property int resolvedEdge: {
    if (!boundsItem || !target || !popupHeight)
      return (preferBelow || edge === Qt.BottomEdge) ? Qt.BottomEdge : Qt.TopEdge;
    const belowOk = targetBottomInBounds + yOffset + popupHeight <= (boundsItem.height || popupHeight);
    const aboveOk = targetTopLeftInBounds.y - yOffset - popupHeight >= 0;
    if (preferBelow || edge === Qt.BottomEdge)
      return belowOk || !aboveOk ? Qt.BottomEdge : Qt.TopEdge;
    return aboveOk || !belowOk ? Qt.TopEdge : Qt.BottomEdge;
  }

  // Candidate/clamped pos in bounds, then mapped to parent
  readonly property point candidatePosInBounds: {
    if (!boundsItem || !target)
      return Qt.point(0, 0);
    const leftIn = targetTopLeftInBounds.x;
    const topIn = targetTopLeftInBounds.y;
    const tw = target.width;
    let xCand = leftIn + xOffset;
    if (hAlign === Qt.AlignRight)
      xCand = leftIn + tw - popupWidth + xOffset;
    else if (hAlign !== Qt.AlignLeft)
      xCand = leftIn + (tw - popupWidth) / 2 + xOffset;
    const yCand = resolvedEdge === Qt.BottomEdge ? targetBottomInBounds + yOffset : topIn - popupHeight - yOffset;
    return Qt.point(xCand, yCand);
  }

  readonly property point clampedPosInBounds: {
    const bw = boundsItem ? boundsItem.width : (parent ? parent.width : popupWidth);
    const bh = boundsItem ? boundsItem.height : (parent ? parent.height : popupHeight);
    const p = candidatePosInBounds;
    const cx = Math.max(0, Math.min(p.x, bw - popupWidth));
    const cy = Math.max(0, Math.min(p.y, bh - popupHeight));
    return Qt.point(cx, cy);
  }

  width: popupWidth
  height: popupHeight
  visible: backgroundRect.opacity > 0

  x: boundsItem && parent ? boundsItem.mapToItem(parent, clampedPosInBounds.x, clampedPosInBounds.y).x : clampedPosInBounds.x
  y: boundsItem && parent ? boundsItem.mapToItem(parent, clampedPosInBounds.x, clampedPosInBounds.y).y : clampedPosInBounds.y

  Rectangle {
    id: backgroundRect

    color: tooltip.bgColor
    radius: tooltip.cornerRadius
    opacity: tooltip.shouldShow ? 1 : 0
    implicitWidth: contentColumn.implicitWidth + 2 * tooltip.hPadding
    implicitHeight: contentColumn.implicitHeight + 2 * tooltip.vPadding

    Behavior on opacity {
      NumberAnimation {
        duration: tooltip.fadeDuration
        easing.type: Easing.OutCubic
      }
    }

    ColumnLayout {
      id: contentColumn
      anchors.centerIn: parent
      spacing: 4

      Loader {
        id: contentLoader
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        active: !!tooltip.contentComponent  // Always load for stable sizing
        sourceComponent: tooltip.contentComponent
        visible: backgroundRect.opacity > 0 && status === Loader.Ready
      }

      Text {
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        color: tooltip.fgColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: tooltip.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
        elide: Text.ElideNone
        visible: backgroundRect.opacity > 0 && tooltip.text.length > 0 && (contentLoader.status !== Loader.Ready || !tooltip.contentComponent)
      }
    }
  }
}
