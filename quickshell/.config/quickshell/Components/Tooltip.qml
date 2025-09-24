pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import qs.Config

Window {
  id: root

  property bool isVisible: false
  readonly property int fadeDuration: Theme.animationDuration
  readonly property color bgColor: Theme.onHoverColor
  readonly property real cornerRadius: Theme.itemRadius
  readonly property color borderColor: Theme.inactiveColor
  readonly property color fgColor: Theme.textContrast(bgColor)
  readonly property real hPadding: 8
  readonly property real vPadding: 4
  readonly property int borderWidth: 1
  property int maxWidth: 420
  property string text: ""
  property Item target: null
  property bool positionAbove: false
  property bool positionLeft: false
  property bool positionRight: false
  property bool wrapText: false

  flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
  color: "transparent"
  visible: false

  readonly property real _minWidth: 50
  readonly property real _minHeight: 40
  readonly property real _hMargin: 12
  readonly property real _vMargin: 12

  width: Math.max(root._minWidth, tooltipText.implicitWidth + root.hPadding * 2)
  height: Math.max(root._minHeight, tooltipText.implicitHeight + root.vPadding * 2)

  function _computePosition(w, h) {
    if (!root.target)
      return;
    let p;
    if (root.positionLeft) {
      p = root.target.mapToGlobal(0, 0);
      root.x = p.x - w - root._hMargin;
      root.y = p.y + (root.target.height - h) / 2;
    } else if (root.positionRight) {
      p = root.target.mapToGlobal(root.target.width, 0);
      root.x = p.x + root._hMargin;
      root.y = p.y + (root.target.height - h) / 2;
    } else if (root.positionAbove) {
      p = root.target.mapToGlobal(0, 0);
      root.x = p.x + (root.target.width - w) / 2;
      root.y = p.y - h - root._vMargin;
    } else {
      p = root.target.mapToGlobal(0, root.target.height);
      root.x = p.x + (root.target.width - w) / 2;
      root.y = p.y + root._vMargin;
    }
  }

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

  // Reposition on content/geometry changes
  onTextChanged: if (root.visible)
    root._computePosition(root.width, root.height)
  onWrapTextChanged: if (root.visible)
    root._computePosition(root.width, root.height)
  onMaxWidthChanged: if (root.visible)
    root._computePosition(root.width, root.height)

  Connections {
    target: root.target
    function onXChanged() {
      if (root.visible)
        root._computePosition(root.width, root.height);
    }
    function onYChanged() {
      if (root.visible)
        root._computePosition(root.width, root.height);
    }
    function onWidthChanged() {
      if (root.visible)
        root._computePosition(root.width, root.height);
    }
    function onHeightChanged() {
      if (root.visible)
        root._computePosition(root.width, root.height);
    }
  }

  Rectangle {
    id: tooltipRect
    anchors.fill: parent
    radius: root.cornerRadius
    color: root.bgColor
    border.color: root.borderColor
    border.width: root.borderWidth
    opacity: 0

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
      text: root.text
      wrapMode: root.wrapText ? Text.Wrap : Text.NoWrap
      width: root.wrapText ? (root.maxWidth - root.hPadding * 2) : implicitWidth
      maximumLineCount: 16
      elide: Text.ElideNone
      color: root.fgColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
  }
}
