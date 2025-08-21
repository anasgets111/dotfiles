pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Services.SystemInfo
import qs.Services
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
                color: ScreenRecordingService.isRecording ? "#e53935" : "#43a047" // red when recording, green when idle

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: ScreenRecordingService.toggleRecording()
                    cursorShape: Qt.PointingHandCursor
                }
            }
            WindowTitle {
                anchors.centerIn: parent
            }
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: TimeService.formattedDateTime + " - " + MainService.username + " - " + TimeService.formatDuration(SystemInfoService.uptime)
                color: "#FFFFFF"
                padding: 12
                font.bold: true
            }
        }
    }
}
