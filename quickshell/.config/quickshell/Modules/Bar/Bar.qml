pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Services.SystemInfo
import qs.Services
import qs.Services.Core
import qs.Services.Utils
import qs.Components

// Minimal top bar scaffold: one layer-surface per screen, top-anchored with reserved space.
Scope {
    id: barRoot

    // Create a bar per connected screen
    Variants {
        model: Quickshell.screens

        WlrLayershell {
            id: layer
            required property var modelData
            color: "#991e1e2e"
            // Bind to this screen
            screen: layer.modelData

            // Top layer suitable for panels
            layer: WlrLayer.Top

            // Reserve space so tiled windows avoid the bar
            // Simple clipboard test button next to record toggle
            Rectangle {
                id: clipboardBtn
                implicitWidth: 100
                implicitHeight: 23
                radius: 4
                anchors.top: parent.top
                anchors.right: recordToggle.left
                anchors.topMargin: 9
                anchors.rightMargin: 10
                border.width: 1
                border.color: "#ffffff80"
                color: "#5c6bc0"

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: clipboardPopup.open()
                    cursorShape: Qt.PointingHandCursor
                }
            }

            // Minimal popup showing cliphist items; no wl-copy integration here
            PopupWindow {
                id: clipboardPopup
                implicitWidth: 420
                implicitHeight: 300
                visible: false
                // Position relative to this bar window, under the bar near the button
                anchor.window: layer
                anchor.rect.x: clipboardBtn.x + clipboardBtn.width - width
                anchor.rect.y: layer.height

                function open() {
                    refresh();
                    visible = true;
                }
                function close() {
                    visible = false;
                }
                function refresh() {
                    ClipboardLiteService.list(function (lines) {
                        itemsModel = lines;
                    }, 30);
                }
                // Model for list
                property var itemsModel: []
                // Live update when service emits changes (delete/wipe/copies by other sources)
                Connections {
                    target: ClipboardLiteService
                    function onChanged() {
                        if (clipboardPopup.visible) {
                            Logger.log("ClipboardTest", "service changed -> refresh");
                            clipboardPopup.refresh();
                        }
                    }
                }

                // Poll for updates while visible to emulate live updates using only the lite service
                Timer {
                    id: clipboardPoll
                    interval: 1200 // ms
                    repeat: true
                    running: clipboardPopup.visible
                    onTriggered: clipboardPopup.refresh()
                }
                // Popup content container
                Rectangle {
                    anchors.fill: parent
                    color: "#1e1e2e"
                    border.width: 1
                    border.color: "#ffffff30"

                    // Header controls and list below
                    // Header
                    Text {
                        id: headerText
                        text: "Clipboard (cliphist)"
                        color: "#fff"
                        font.bold: true
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: 8
                        anchors.topMargin: 8
                    }
                    Rectangle {
                        id: closeBtn
                        width: 60
                        height: 24
                        radius: 4
                        color: "#455a64"
                        border.width: 1
                        border.color: "#ffffff30"
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 8
                        anchors.rightMargin: 8
                        MouseArea {
                            anchors.fill: parent
                            onClicked: clipboardPopup.close()
                        }
                        Text {
                            anchors.centerIn: parent
                            color: "#fff"
                            text: "Close"
                            font.pixelSize: 12
                        }
                    }
                    Rectangle {
                        id: refreshBtn
                        width: 70
                        height: 24
                        radius: 4
                        color: "#3949ab"
                        border.width: 1
                        border.color: "#ffffff30"
                        anchors.top: parent.top
                        anchors.right: closeBtn.left
                        anchors.topMargin: 8
                        anchors.rightMargin: 6
                        MouseArea {
                            anchors.fill: parent
                            onClicked: clipboardPopup.refresh()
                        }
                        Text {
                            anchors.centerIn: parent
                            color: "#fff"
                            text: "Refresh"
                            font.pixelSize: 12
                        }
                    }
                    Rectangle {
                        id: wipeBtn
                        width: 60
                        height: 24
                        radius: 4
                        color: "#8e24aa"
                        border.width: 1
                        border.color: "#ffffff30"
                        anchors.top: parent.top
                        anchors.right: refreshBtn.left
                        anchors.topMargin: 8
                        anchors.rightMargin: 6
                        MouseArea {
                            anchors.fill: parent
                            onClicked: ClipboardLiteService.wipe(function () {})
                        }
                        Text {
                            anchors.centerIn: parent
                            color: "#fff"
                            text: "Wipe"
                            font.pixelSize: 12
                        }
                    }

                    // List
                    ListView {
                        id: list
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.top: headerText.bottom
                        anchors.margins: 6
                        model: clipboardPopup.itemsModel
                        clip: true
                        delegate: Rectangle {
                            id: delegateRoot
                            required property int index
                            required property var modelData
                            width: list.width
                            height: Math.max(28, textItem.implicitHeight + 10)
                            color: delegateRoot.index % 2 ? "#2a2a3a" : "#242436"
                            border.color: "#ffffff12"
                            border.width: 1

                            Text {
                                id: textItem
                                anchors.fill: parent
                                anchors.margins: 6
                                color: "#eee"
                                elide: Text.ElideRight
                                text: delegateRoot.modelData
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function (mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        var picked = String(delegateRoot.modelData || "");
                                        clipboardPopup.close();
                                        ClipboardLiteService.copyAndPasteFromLine(picked, {
                                            primary: false,
                                            delayMs: 200
                                        }, function (ok) {});
                                    } else if (mouse.button === Qt.RightButton) {
                                        Logger.log("ClipboardTest", "delete attempt for:", delegateRoot.modelData);
                                        ClipboardLiteService.deleteFromLine(delegateRoot.modelData, function (ok) {
                                            Logger.log("ClipboardTest", "delete result:", ok);
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            }
            exclusionMode: ExclusionMode.Auto

            // Position across the top edge
            anchors.top: true
            anchors.left: true
            anchors.right: true

            // Bar height (tweak as desired)
            implicitHeight: 36

            // Optional: namespace for external tools
            namespace: "qs-bar"

            // Placeholder background; replace with real content later
            // Simple recording toggle button
            Rectangle {
                id: recordToggle
                implicitWidth: 80
                implicitHeight: 23
                radius: 4
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 9
                anchors.rightMargin: 10
                border.width: 1
                border.color: "#ffffff80"
                color: ScreenRecordingService.isRecording ? "#e53935" : "#43a047"

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: ScreenRecordingService.toggleRecording()
                    cursorShape: Qt.PointingHandCursor
                }

                Connections {
                    target: ScreenRecordingService
                    function onRecordingStarted(path) {
                        console.log("Recording started:", path);
                    }
                    function onRecordingStopped(path) {
                        console.log("Recording stopped:", path);
                    }
                }
            }
            WindowTitle {
                anchors.centerIn: parent
            }
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: TimeService.currentTime + " - " + TimeService.currentDate + " - " + MainService.username + " - " + TimeService.formatDuration(SystemInfoService.uptime)
                color: "#FFFFFF"
                padding: 12
                font.bold: true
            }
        }
    }
}
