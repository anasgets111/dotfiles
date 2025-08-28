import QtQuick
import Quickshell

PopupWindow {
  id: popupRoot

  property int alignment: Qt.AlignHCenter
  property Item anchorItem
  default property alias contentItem: popupContent.data
  property int gravity: Qt.BottomEdge

  color: Theme.panelWindowColor

  anchor {
    gravity: gravity
    item: anchorItem
    margins.top: Theme.popupOffset
    rect.x: anchorItem ? (anchorItem.width - implicitWidth) / 2 : 0
  }
  Rectangle {
    id: popupContent

    anchors.fill: parent
    anchors.topMargin: Theme.popupOffset
    border.color: Theme.borderColor
    color: Theme.bgColor
    opacity: 0.97
    radius: Theme.itemRadius
  }
  MouseArea {
    acceptedButtons: Qt.RightButton
    anchors.fill: parent
    hoverEnabled: false
    propagateComposedEvents: true

    onClicked: popupRoot.visible = false
  }
}
