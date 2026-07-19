pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Config

PopupWindow {
  id: root

  readonly property real _hPadding: Theme.spacingSm
  readonly property int _minHeight: Theme.controlHeightMd
  readonly property int _minWidth: Theme.controlWidthLg
  property real _mouseX: 0
  property real _mouseY: 0
  readonly property real _vPadding: Theme.spacingXs
  readonly property color bgColor: Theme.onHoverColor
  readonly property color borderColor: Theme.inactiveColor
  readonly property int borderWidth: Theme.borderWidthThin
  default property alias content: contentContainer.data
  readonly property real cornerRadius: Theme.radiusMd
  readonly property int fadeDuration: Theme.animationDuration
  readonly property color fgColor: Theme.textContrast(bgColor)
  readonly property bool hasCustomContent: contentContainer.children.length > 0
  property bool isVisible: false
  property int maxWidth: 420
  property real mouseOffsetX: 8
  property real mouseOffsetY: 8
  property bool positionAbove: false
  property bool positionAtMouse: false
  property bool positionLeft: false
  property bool positionRight: false
  property Item target: null
  property string text: ""
  property bool wrapText: false

  // Quickshell._Window exposes this as PopupAnchor from its parent module, but
  // qmllint disable unresolved-type missing-type
  function updateAnchor(): void {
    if (root.visible)
      root.anchor.updateAnchor();
  }

  anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
  anchor.edges: root.positionAtMouse ? Edges.Top | Edges.Left : root.positionLeft ? Edges.Left : root.positionRight ? Edges.Right : root.positionAbove ? Edges.Top : Edges.Bottom
  anchor.gravity: root.positionAtMouse ? Edges.Bottom | Edges.Right : root.positionLeft ? Edges.Left : root.positionRight ? Edges.Right : root.positionAbove ? Edges.Top : Edges.Bottom
  anchor.item: root.target
  anchor.rect: root.positionAtMouse ? Qt.rect(root._mouseX + root.mouseOffsetX, root._mouseY + root.mouseOffsetY, 1, 1) : root.positionLeft ? Qt.rect(-Theme.spacingMd, (root.target?.height ?? 0) / 2, 1, 1) : root.positionRight ? Qt.rect((root.target?.width ?? 0) + Theme.spacingMd, (root.target?.height ?? 0) / 2, 1, 1) : root.positionAbove ? Qt.rect((root.target?.width ?? 0) / 2, -Theme.spacingMd, 1, 1) : Qt.rect((root.target?.width ?? 0) / 2, (root.target?.height ?? 0) + Theme.spacingMd, 1, 1)
  // qmllint enable unresolved-type missing-type
  color: "transparent"
  implicitHeight: root.hasCustomContent ? Math.max(root._minHeight, contentContainer.implicitHeight + root._vPadding * 2) : Math.max(root._minHeight, tooltipText.implicitHeight + root._vPadding * 2)
  implicitWidth: root.hasCustomContent ? Math.max(root._minWidth, contentContainer.implicitWidth + root._hPadding * 2) : Math.max(root._minWidth, tooltipText.implicitWidth + root._hPadding * 2)
  surfaceFormat.opaque: false
  visible: false

  onHeightChanged: root.updateAnchor()
  onIsVisibleChanged: {
    if (root.isVisible && root.target !== null) {
      if (!root.visible) {
        root.visible = true;
        tooltipRect.opacity = 0;
      }
      root.updateAnchor();
      tooltipRect.opacity = 1;
    } else if (root.visible) {
      tooltipRect.opacity = 0;
    }
  }
  onWidthChanged: root.updateAnchor()
  on_MouseXChanged: if (root.positionAtMouse)
    root.updateAnchor()
  on_MouseYChanged: if (root.positionAtMouse)
    root.updateAnchor()

  Connections {
    function onHeightChanged(): void {
      root.updateAnchor();
    }
    function onWidthChanged(): void {
      root.updateAnchor();
    }
    function onXChanged(): void {
      root.updateAnchor();
    }
    function onYChanged(): void {
      root.updateAnchor();
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
      font.pixelSize: Theme.fontMd
      horizontalAlignment: Text.AlignHCenter
      maximumLineCount: 16
      text: root.text
      verticalAlignment: Text.AlignVCenter
      visible: !root.hasCustomContent
      width: root.wrapText ? (root.maxWidth - root._hPadding * 2) : implicitWidth
      wrapMode: root.wrapText ? Text.Wrap : Text.NoWrap
    }
    Item {
      id: contentContainer

      anchors.centerIn: parent
      implicitHeight: childrenRect.height
      implicitWidth: childrenRect.width
      visible: root.hasCustomContent
    }
  }
}
