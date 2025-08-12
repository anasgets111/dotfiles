import QtQuick
import Quickshell.Wayland
import "../services" as Services

Item {
    id: root
    required property var screen // ShellScreen

    visible: false
    width: 1
    height: 1

    ScreencopyView {
        id: screencopy
        anchors.fill: parent
        captureSource: root.screen
        live: false
        paintCursor: false

        // No screenshot saving or caching needed; live ScreencopyView is used for lock background

        onStopped: {
            console.warn("[DesktopCapture] screencopy stopped (screen object)");
        }
    }

    // If the compositor is a bit slow, try once more
    Timer {
        id: retryTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (!screencopy.hasContent && Services.LockService.prelockInProgress) {
                console.debug("[DesktopCapture] retry captureFrame()");
                screencopy.captureFrame();
            }
        }
    }

    // No LockService connections needed for lock screen anymore
}
