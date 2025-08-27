pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Services.SystemInfo
import Qt5Compat.GraphicalEffects

Control {
    id: card
    // Use a generic type to avoid static analysis errors when reading custom fields
    required property var wrapper
    signal dismiss
    signal actionTriggered(string id)
    signal replySubmitted(string text)

    // Use project service to resolve urgency to avoid importing backend enums
    readonly property bool critical: NotificationService._urgencyToString(wrapper?.urgency) === "critical"
    readonly property bool low: NotificationService._urgencyToString(wrapper?.urgency) === "low"

    implicitWidth: 360
    padding: 10
    background: Rectangle {
        radius: 8
        color: card.critical ? Qt.rgba(0.35, 0.05, 0.05, 0.96) : card.low ? Qt.rgba(0.12, 0.12, 0.12, 0.96) : Qt.rgba(0.16, 0.16, 0.16, 0.96)
        border.color: card.critical ? "#ff5555" : "#2a2a2a"
        border.width: 1
        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            radius: 16
            samples: 25
            color: Qt.rgba(0, 0, 0, 0.5)
        }
    }

    contentItem: ColumnLayout {
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Image {
                source: card.wrapper.iconSource
                fillMode: Image.PreserveAspectFit
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                sourceSize.width: 64
                sourceSize.height: 64
                smooth: true
                visible: !!source
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: card.wrapper.summary || "(No title)"
                        color: "white"
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: card.wrapper.timeStr
                        color: "#bbbbbb"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: card.wrapper.bodySafe
                    color: "#dddddd"
                    wrapMode: Text.Wrap
                    textFormat: card.wrapper.bodyFormat === "markup" ? Text.RichText : Text.PlainText
                    maximumLineCount: 6
                    elide: Text.ElideRight
                    onLinkActivated: url => Qt.openUrlExternally(url)
                }
            }

            ToolButton {
                icon.name: "window-close"
                text: "×"
                onClicked: card.dismiss()
            }
        }

        Image {
            Layout.fillWidth: true
            visible: !!card.wrapper.imageSource
            source: card.wrapper.imageSource
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 512
            sourceSize.height: 256
            smooth: true
            antialiasing: true
            Layout.preferredHeight: visible ? implicitHeight : 0
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: !!card.wrapper.replyModel?.enabled && !card.wrapper.replyModel?.submitted

            TextField {
                id: replyField
                Layout.fillWidth: true
                placeholderText: card.wrapper.replyModel?.placeholder || "Reply..."
                maximumLength: Math.max(0, Number(card.wrapper.replyModel?.maxLength || 0))
            }
            Button {
                text: "Send"
                enabled: {
                    const min = Math.max(0, Number(card.wrapper.replyModel?.minLength || 0));
                    return replyField.text.length >= min;
                }
                onClicked: card.replySubmitted(replyField.text)
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: card.wrapper.actionsModel
                delegate: Button {
                    required property var modelData
                    text: modelData.title || modelData.id
                    icon.source: modelData.iconSource || ""
                    onClicked: card.actionTriggered(String(modelData.id))
                }
            }
            visible: (card.wrapper.actionsModel || []).length > 0
        }

        Rectangle {
            Layout.fillWidth: true
            visible: cardTimeout > 0
            Layout.preferredHeight: 3
            radius: 2
            color: "#333333"
            property real cardTimeout: card.wrapper.timer.interval
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                radius: parent.radius
                color: card.critical ? "#ff5555" : "#5aa0ff"
                width: (progress === undefined ? parent.width : progress * parent.width)
                property real progress
                NumberAnimation on progress {
                    id: anim
                    from: 1.0
                    to: 0.0
                    duration: card.wrapper.timer.interval
                    running: card.wrapper.timer.interval > 0
                    easing.type: Easing.Linear
                }
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 150
        }
    }
    // Drive opacity directly instead of states for simpler parsing
    opacity: card.wrapper.popup ? 1.0 : 0.0

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: if (card.wrapper.timer.running)
            card.wrapper.timer.stop()
        onExited: if (card.wrapper.timer.interval > 0 && !card.wrapper.timer.running)
            card.wrapper.timer.start()
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: card.dismiss()
        hoverEnabled: false
        propagateComposedEvents: true
    }

    Keys.onEscapePressed: card.dismiss()
}
