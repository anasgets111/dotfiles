import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Services.SystemInfo

// Minimal notifications popup using SystemInfo.NotificationService
Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: layer
        required property var modelData
        screen: layer.modelData
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        color: "transparent"
        visible: true
        mask: Region {
            item: content
        }
        Column {
            id: content
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
            spacing: 8
            width: 320

            Repeater {
                model: NotificationService.visible
                delegate: Rectangle {
                    id: notif
                    // Wrapper object from NotificationService.visible
                    required property var modelData
                    property var w: notif.modelData

                    // Trigger an action on the underlying notification
                    function _trigger(actionId) {
                        if (!notif.w || !notif.w.notification)
                            return;
                        const n = notif.w.notification;
                        if (typeof n.invokeAction === 'function')
                            n.invokeAction(String(actionId));
                        else if (typeof n.activateAction === 'function')
                            n.activateAction(String(actionId));
                    }

                    width: parent.width
                    radius: 10
                    color: "#1f2430"
                    border.color: "#2f3441"
                    border.width: 1
                    clip: true
                    implicitHeight: inner.implicitHeight + 24
                    visible: !!notif.w

                    // urgency accent stripe
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        radius: 2
                        color: (Number(notif.w.urgency) >= 2) ? "#e06c75" : (Number(notif.w.urgency) <= 0 ? "#8a8f98" : "#61afef")
                    }

                    Column {
                        id: inner
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 8

                        Row {
                            spacing: 6
                            Text {
                                text: (notif.w.appName || "App")
                                color: "#b7c0cc"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                            Item {
                                width: 1
                                height: 1
                            }
                            Text {
                                text: notif.w.timeStr || ""
                                color: "#c8ccd4"
                                font.pixelSize: 12
                            }
                        }

                        Text {
                            text: notif.w.summary || "Notification"
                            color: "#e9ecf1"
                            font.pixelSize: 15
                            font.bold: true
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            width: parent.width
                            maximumLineCount: 3
                        }

                        Text {
                            text: notif.w.body || ""
                            color: "#c2c7d0"
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            width: parent.width
                            maximumLineCount: 6
                        }

                        // Actions row (if any)
                        Item {
                            id: actionsBlock
                            width: parent.width
                            height: actionsFlow.implicitHeight
                            visible: actionsModel.length > 0

                            // Normalize actions from different possible shapes
                            property var actionsModel: {
                                const n = notif.w && notif.w.notification ? notif.w.notification : null;
                                const a = n && n.actions ? n.actions : [];
                                if (!a || a.length === 0)
                                    return [];
                                // Flat pair array: [id, title, id, title, ...]
                                if (typeof a[0] === 'string') {
                                    const out = [];
                                    for (var i = 0; i + 1 < a.length; i += 2) {
                                        const id = a[i];
                                        const title = a[i + 1];
                                        out.push({
                                            id,
                                            title,
                                            trigger: function () {
                                                if (!n)
                                                    return;
                                                if (typeof n.invokeAction === 'function')
                                                    n.invokeAction(String(id));
                                                else if (typeof n.activateAction === 'function')
                                                    n.activateAction(String(id));
                                            }
                                        });
                                    }
                                    return out;
                                }
                                // Array of objects with common keys: normalize to consistent shape
                                return a.map(function (x) {
                                    const id = x.id || x.action || x.key || x.name || "";
                                    const title = x.title || x.label || x.text || String(id);
                                    const hasInvoke = typeof x.invoke === 'function';
                                    const hasActivate = typeof x.activate === 'function';
                                    return {
                                        id,
                                        title,
                                        trigger: function () {
                                            if (hasInvoke)
                                                x.invoke();
                                            else if (hasActivate)
                                                x.activate();
                                            else if (n) {
                                                if (typeof n.invokeAction === 'function')
                                                    n.invokeAction(String(id));
                                                else if (typeof n.activateAction === 'function')
                                                    n.activateAction(String(id));
                                            }
                                        }
                                    };
                                });
                            }

                            Flow {
                                id: actionsFlow
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: actionsBlock.actionsModel
                                    delegate: Rectangle {
                                        id: actionBtn
                                        required property var modelData
                                        radius: 6
                                        color: mouseAct.containsMouse ? "#384054" : "#2e3443"
                                        border.color: "#455069"
                                        height: 26
                                        implicitWidth: label.implicitWidth + 16
                                        Text {
                                            id: label
                                            anchors.centerIn: parent
                                            text: (actionBtn.modelData.title || actionBtn.modelData.label || actionBtn.modelData.text || String(actionBtn.modelData.id || actionBtn.modelData.action || actionBtn.modelData.key || actionBtn.modelData.name || ""))
                                            color: mouseAct.containsMouse ? "#eef2f8" : "#cbd2dc"
                                            font.pixelSize: 12
                                        }
                                        MouseArea {
                                            id: mouseAct
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: if (actionBtn.modelData && typeof actionBtn.modelData.trigger === 'function')
                                                actionBtn.modelData.trigger()
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            spacing: 8
                            Rectangle {
                                id: closeBtn
                                width: 20
                                height: 20
                                radius: 4
                                color: mouse.containsMouse ? "#3a4150" : "#2a303c"
                                border.color: "#434a59"
                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: mouse.containsMouse ? "#eef2f8" : "#c8ccd4"
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationService.dismissNotification(notif.w)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
