import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Services.SystemInfo
import QtQuick.Controls
import QtQuick.Effects

// ToastManager overlay hooked to OSDService
PanelWindow {
    id: root

    property var modelData

    // screen: MainService.mainMon
    visible: OSDService.toastVisible
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    Rectangle {
        id: toast
        // Bottom-up width: sized to content, clamped by maxContentWidth
        width: Math.min(maxContentWidth + (padding * 2), contentCol.implicitWidth + (padding * 2))
        height: contentCol.implicitHeight + (padding * 2)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        radius: 12
        color: "transparent"
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(0.10, 0.08, 0.12, 0.92)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(0.10, 0.08, 0.12, 0.82)
            }
        }
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        clip: true
        visible: OSDService.toastVisible
        opacity: OSDService.toastVisible ? 1 : 0
        y: OSDService.toastVisible ? 0 : 16
        scale: OSDService.toastVisible ? 1 : 0.98
        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutQuad
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutQuad
            }
        }

        property int padding: 12
        property int spacing: 6
        // Cap content width relative to screen; avoids binding loops by not depending on toast.width
        property int maxContentWidth: Math.round(parent.width * 0.15)
        // Progress from 1 -> 0 for the progress bar
        property real toastProgress: 0.0

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 30
            shadowVerticalOffset: 6
        }

        // Content
        Column {
            id: contentCol
            anchors.fill: parent
            anchors.margins: toast.padding
            spacing: toast.spacing

            // Header row: level badge + message + optional repeat count
            Row {
                spacing: 8
                anchors.horizontalCenter: undefined

                // Level badge
                Rectangle {
                    id: levelBadge
                    radius: 4
                    height: levelText.implicitHeight + 4
                    width: levelText.implicitWidth + 8
                    color: {
                        switch (OSDService.currentLevel) {
                        case OSDService.levelError:
                            return Qt.rgba(0.90, 0.28, 0.32, 1);
                        case OSDService.levelWarn:
                            return Qt.rgba(0.98, 0.73, 0.20, 1);
                        default:
                            return Qt.rgba(0.40, 0.70, 1.0, 1);
                        }
                    }
                    Text {
                        id: levelText
                        anchors.centerIn: parent
                        text: (OSDService.currentLevel === OSDService.levelError ? "⛔ ERROR" : OSDService.currentLevel === OSDService.levelWarn ? "⚠️ WARN" : "ℹ️ INFO")
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                        font.letterSpacing: 0.5
                    }
                }

                // Main message
                Text {
                    text: OSDService.currentMessage
                    color: "white"
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    // Constrain to available space after badge and repeat chip
                    width: Math.min(implicitWidth, Math.max(0, toast.maxContentWidth - (levelBadge.width + (repChip.visible ? repChip.width : 0) + 16)))
                }

                // Repeat count chip
                Rectangle {
                    id: repChip
                    visible: OSDService.currentRepeatCount > 0
                    radius: 8
                    height: repText.implicitHeight + 4
                    width: repText.implicitWidth + 10
                    color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 0
                    Text {
                        id: repText
                        anchors.centerIn: parent
                        text: "×" + (OSDService.currentRepeatCount + 1)
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }

            // Details (optional)
            Text {
                visible: OSDService.hasDetails
                text: OSDService.currentDetails
                color: "white"
                opacity: 0.9
                font.pixelSize: 14
                font.weight: Font.Normal
                wrapMode: Text.Wrap
                width: Math.min(implicitWidth, toast.maxContentWidth)
            }

            // Status line (queue, DND)
            Row {
                spacing: 12
                opacity: 0.9

                Text {
                    text: "📥 Queue: " + OSDService.toastQueue.length
                    color: "white"
                    font.pixelSize: 12
                }
                Text {
                    text: OSDService.doNotDisturb ? "🔕 DND: on" : "🔔 DND: off"
                    color: "white"
                    font.pixelSize: 12
                }
            }

            // Wallpaper error status (optional external status)
            Text {
                visible: OSDService.wallpaperErrorStatus.length > 0
                text: OSDService.wallpaperErrorStatus
                color: "white"
                opacity: 0.95
                font.pixelSize: 12
                wrapMode: Text.Wrap
                width: Math.min(implicitWidth, toast.maxContentWidth)
            }
        }
        // Progress bar: rounded track + clipped fill, inset to avoid corner overlap
        Rectangle {
            id: progressTrack
            height: 1
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.10)
            width: Math.max(0, Math.min(contentCol.width - 4, toast.maxContentWidth - 4))
            anchors.horizontalCenter: parent.horizontalCenter
            clip: true

            Rectangle {
                id: progressFill
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                radius: parent.radius
                width: parent.width * toast.toastProgress
                color: Qt.rgba(0.80, 0.70, 1.00, 0.90) // mauve accent
            }
        }
    }

    Connections {
        target: OSDService
        function onResetToastState() {
            // Optionally reset animation or position here
            toast.opacity = 1;
            // Restart progress animation
            toast.toastProgress = 1.0;
            progressAnim.stop();
            progressAnim.duration = root._baseDurationFor(OSDService.currentLevel, OSDService.hasDetails);
            progressAnim.start();
        }
    }
    mask: Region {
        item: toast
    }

    // Local helpers and animations (scoped at root to avoid binding loops)
    function _baseDurationFor(level, hasDetails) {
        if (level === OSDService.levelError && hasDetails)
            return OSDService.durationErrorWithDetails;
        if (level === OSDService.levelError)
            return OSDService.durationError;
        if (level === OSDService.levelWarn)
            return OSDService.durationWarn;
        return OSDService.durationInfo;
    }

    // Animate toast progress from 1 -> 0 each time a toast starts/reset
    NumberAnimation {
        id: progressAnim
        target: toast
        property: "toastProgress"
        from: 1.0
        to: 0.0
        duration: 3000 // will be overridden on start
        easing.type: Easing.Linear
        running: false
    }
}
