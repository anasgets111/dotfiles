pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import qs.Services.SystemInfo
import QtQuick.Window

PanelWindow {
    id: layer
    visible: NotificationService.visible.length > 0
    required property var modelData
    // Guard against undefined to avoid assignment warnings; null is acceptable
    screen: layer.modelData || null
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    mask: Region {
        item: popupColumn
    }
    property int margin: 12
    property int barOffset: 36
    // property int shadowPad: 16
    Column {
        id: popupColumn
        anchors {
            top: parent.top
            right: parent.right
            topMargin: layer.margin + layer.barOffset
            rightMargin: layer.margin
        }
        spacing: 8
        Repeater {
            model: NotificationService.visible
            delegate: Item {
                id: del
                required property var modelData
                implicitWidth: card.implicitWidth
                width: implicitWidth
                height: card.implicitHeight
                NotificationCard {
                    id: card
                    wrapper: del.modelData
                    onDismiss: NotificationService.dismissNotification(del.modelData)
                    onActionTriggered: actionId => NotificationService.executeAction(del.modelData.id, actionId)
                    onReplySubmitted: text => {
                        const r = NotificationService.reply(del.modelData.id, text);
                        if (r?.ok)
                            del.modelData.popup = false;
                    }
                }
            }
        }
    }
    Rectangle {
        id: dndBanner
        visible: NotificationService.dndPolicy?.enabled
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        radius: 6
        color: Qt.rgba(0.95, 0.55, 0.10, 0.9)
        width: txt.implicitWidth + 24
        height: 28
        Text {
            id: txt
            anchors.centerIn: parent
            color: "black"
            text: "Do Not Disturb: " + (NotificationService.dndPolicy?.behavior === "suppress" ? "Suppress" : "Queue")
        }
    }
}
