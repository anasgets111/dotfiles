pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config

PopupWindow {
  id: root

  readonly property real _hPadding: Theme.spacingSm
  property real _mouseX: 0
  property real _mouseY: 0
  readonly property real _vPadding: Theme.spacingXs
  readonly property color bgColor: Theme.glassSurfaceColor
  readonly property Region blurRegion: Region {
    item: tooltipRect
    radius: tooltipRect.radius
  }
  default property alias content: contentContainer.data
  readonly property color fgColor: Theme.textContrast(bgColor)
  readonly property bool hasCustomContent: contentContainer.children.length > 0
  property bool isVisible: false
  property real mouseOffsetX: 8
  property real mouseOffsetY: 8
  property bool positionAtMouse: false
  property Item target: null
  property string text: ""

  // PopupAnchor is provided dynamically by Quickshell._Window.
  // qmllint disable unresolved-type missing-type
  function updateAnchor(): void {
    if (root.visible)
      root.anchor.updateAnchor();
  }

  BackgroundEffect.blurRegion: root.blurRegion
  anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
  anchor.edges: root.positionAtMouse ? Edges.Top | Edges.Left : Edges.Bottom
  anchor.gravity: root.positionAtMouse ? Edges.Bottom | Edges.Right : Edges.Bottom
  anchor.item: root.target
  anchor.rect: root.positionAtMouse ? Qt.rect(root._mouseX + root.mouseOffsetX, root._mouseY + root.mouseOffsetY, 1, 1) : Qt.rect((root.target?.width ?? 0) / 2, (root.target?.height ?? 0) + Theme.spacingMd, 1, 1)
  // qmllint enable unresolved-type missing-type

  color: "transparent"
  implicitHeight: Math.max(Theme.controlHeightMd, (root.hasCustomContent ? contentContainer.implicitHeight : tooltipText.implicitHeight) + root._vPadding * 2)
  implicitWidth: Math.max(Theme.controlWidthLg, (root.hasCustomContent ? contentContainer.implicitWidth : tooltipText.implicitWidth) + root._hPadding * 2)
  surfaceFormat.opaque: false
  visible: false

  mask: Region {
  }

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
    border.color: Theme.glassBorderColor
    border.width: Theme.borderWidthThin
    color: root.bgColor
    opacity: 0
    radius: Theme.radiusMd

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.OutCubic
      }
    }

    onOpacityChanged: if (opacity === 0 && !root.isVisible)
      root.visible = false

    OText {
      id: tooltipText

      anchors.centerIn: parent
      color: root.fgColor
      horizontalAlignment: Text.AlignHCenter
      text: root.text
      visible: !root.hasCustomContent
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
