import QtQuick
import Quickshell


PopupWindow {
    id: popupRoot

    // The item to anchor the popup to (e.g., a bar widget)
    property Item anchorItem

    // Gravity and alignment for popup placement
    property int gravity: Qt.BottomEdge
    property int alignment: Qt.AlignHCenter
    color : Theme.panelWindowColor
    // Content for the popup
    default property alias contentItem: popupContent.data

    // Anchor the popup below the anchorItem
    anchor {
        item: anchorItem
        gravity: gravity
        // Center horizontally below anchorItem
        rect.x: anchorItem ? (anchorItem.width - implicitWidth) / 2 : 0
        // Vertical offset below anchorItem
        margins.top: Theme.popupOffset
    }


    // Example styling: rounded rectangle background
    Rectangle {
        id: popupContent
        anchors.fill: parent
        anchors.topMargin: Theme.popupOffset
        radius: Theme.itemRadius
        color: Theme.bgColor
        border.color: Theme.borderColor
        border.width: Theme.borderWidth
        opacity: 0.97
        // Content goes here via default property
    }

    // Optional: dismiss popup on click outside
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: popupRoot.visible = false
        propagateComposedEvents: true
        hoverEnabled: false
        // Only dismiss on right-click, can be customized
    }
}
