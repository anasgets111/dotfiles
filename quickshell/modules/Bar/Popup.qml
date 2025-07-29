import QtQuick
import Quickshell

PopupWindow {
    id: popupRoot

    property Item anchorItem

    property int gravity: Qt.BottomEdge
    property int alignment: Qt.AlignHCenter
    color: Theme.panelWindowColor
    default property alias contentItem: popupContent.data

    anchor {
        item: anchorItem
        gravity: gravity
        rect.x: anchorItem ? (anchorItem.width - implicitWidth) / 2 : 0
        margins.top: Theme.popupOffset
    }

    Rectangle {
        id: popupContent
        anchors.fill: parent
        anchors.topMargin: Theme.popupOffset
        radius: Theme.itemRadius
        color: Theme.bgColor
        border.color: Theme.borderColor
        border.width: Theme.borderWidth
        opacity: 0.97
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: popupRoot.visible = false
        propagateComposedEvents: true
        hoverEnabled: false
    }
}
