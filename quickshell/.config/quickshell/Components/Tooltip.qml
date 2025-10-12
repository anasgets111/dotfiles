pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import qs.Config

Item {
  id: root

  readonly property real _hMargin: 12
  readonly property real _minHeight: 40
  readonly property real _minWidth: 50
  readonly property real _vMargin: 12
  readonly property color bgColor: Theme.onHoverColor
  readonly property color borderColor: Theme.inactiveColor
  readonly property int borderWidth: 1
  readonly property real cornerRadius: Theme.itemRadius
  readonly property int fadeDuration: Theme.animationDuration
  readonly property color fgColor: Theme.textContrast(bgColor)
  readonly property real hPadding: 8
  property bool isVisible: false
  property int maxWidth: 420
  readonly property Item overlayParent: {
    if (!root.target)
      return null;
    const attached = root.target.Window;
    const win = attached ? attached.window : null;
    return win ? win.contentItem : null;
  }
  property bool positionAbove: false
  property bool positionLeft: false
  property bool positionRight: false
  property Item target: null
  property string text: ""
  readonly property real vPadding: 4
  property bool wrapText: false

  function _computePosition(w, h) {
    if (!root.target || !root.parent)
      return;
    let p;
    if (root.positionLeft) {
      p = root.target.mapToItem(root.parent, 0, 0);
      root.x = p.x - w - root._hMargin;
      root.y = p.y + (root.target.height - h) / 2;
    } else if (root.positionRight) {
      p = root.target.mapToItem(root.parent, root.target.width, 0);
      root.x = p.x + root._hMargin;
      root.y = p.y + (root.target.height - h) / 2;
    } else if (root.positionAbove) {
      p = root.target.mapToItem(root.parent, 0, 0);
      root.x = p.x + (root.target.width - w) / 2;
      root.y = p.y - h - root._vMargin;
    } else {
      p = root.target.mapToItem(root.parent, 0, root.target.height);
      root.x = p.x + (root.target.width - w) / 2;
      root.y = p.y + root._vMargin;
    }

    const parentItem = root.parent;
    if (!parentItem || parentItem.width <= 0 || parentItem.height <= 0)
      return;

    const minX = root._hMargin;
    const maxX = parentItem.width - w - root._hMargin;
    const minY = root._vMargin;
    const maxY = parentItem.height - h - root._vMargin;

    function clamp(value, min, max) {
      if (max < min)
        return min;
      if (value < min)
        return min;
      if (value > max)
        return max;
      return value;
    }

    root.x = clamp(root.x, minX, maxX);
    root.y = clamp(root.y, minY, maxY);
  }

  height: Math.max(root._minHeight, tooltipText.implicitHeight + root.vPadding * 2)
  parent: overlayParent
  visible: false
  width: Math.max(root._minWidth, tooltipText.implicitWidth + root.hPadding * 2)

  onIsVisibleChanged: {
    if (!root.target)
      return;
    if (root.isVisible) {
      root._computePosition(root.width, root.height);
      if (!root.visible) {
        root.visible = true;
        tooltipRect.opacity = 0;
      }
      tooltipRect.opacity = 1;
    } else if (root.visible) {
      tooltipRect.opacity = 0;
    }
  }
  onMaxWidthChanged: if (root.visible)
    root._computePosition(root.width, root.height)
  onParentChanged: if (root.visible)
    root._computePosition(root.width, root.height)

  // Reposition on content/geometry changes
  onTextChanged: if (root.visible)
    root._computePosition(root.width, root.height)
  onWrapTextChanged: if (root.visible)
    root._computePosition(root.width, root.height)

  Connections {
    function onHeightChanged() {
      if (root.visible)
        root._computePosition(root.width, root.height);
    }

    function onWidthChanged() {
      if (root.visible)
        root._computePosition(root.width, root.height);
    }

    function onXChanged() {
      if (root.visible)
        root._computePosition(root.width, root.height);
    }

    function onYChanged() {
      if (root.visible)
        root._computePosition(root.width, root.height);
    }

    target: root.target
  }

  Rectangle {
    id: tooltipRect

    anchors.fill: parent
    border.color: root.borderColor
    border.width: root.borderWidth
    color: root.bgColor
    opacity: 0
    radius: root.cornerRadius

    Behavior on opacity {
      NumberAnimation {
        duration: root.fadeDuration
        easing.type: Easing.OutCubic

        onStopped: if (tooltipRect.opacity === 0)
          root.visible = false
      }
    }

    Text {
      id: tooltipText

      anchors.centerIn: parent
      color: root.fgColor
      elide: Text.ElideNone
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      horizontalAlignment: Text.AlignHCenter
      maximumLineCount: 16
      text: root.text
      verticalAlignment: Text.AlignVCenter
      width: root.wrapText ? (root.maxWidth - root.hPadding * 2) : implicitWidth
      wrapMode: root.wrapText ? Text.Wrap : Text.NoWrap
    }
  }
}
