pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Widgets

Item {
    id: root

    property var device: UPower.displayDevice
    // Clamp to [0, 1] to avoid jitter or invalid values from the service
    property real percentage: Math.max(0, Math.min(device.percentage, 1))
    property bool isCharging: device.state === UPowerDeviceState.Charging
    property bool isPluggedIn: device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge
    property bool isLowAndNotCharging: DetectEnv.isLaptopBattery && percentage <= 0.2 && !isCharging
    property bool isCriticalAndNotCharging: DetectEnv.isLaptopBattery && percentage <= 0.1 && !isCharging
    property bool isSuspendingAndNotCharging: DetectEnv.isLaptopBattery && percentage <= 0.05 && !isCharging

    property real overlayFlashWidth: 2
    property real overlayFlashX: implicitWidth / 2 - overlayFlashWidth / 2
    property int widthPhase: 0
    property string batteryIcon: {
        if (root.isCharging)
            return "";
        if (root.device.state === UPowerDeviceState.PendingCharge)
            return "󰂄";

        var icons = ["", "", "", "", ""];
        var index = Math.min(Math.floor(root.percentage * 5), 4);
        return icons[index];
    }

    visible: DetectEnv.isLaptopBattery
    implicitHeight: Theme.itemHeight
    implicitWidth: 80

    onIsPluggedInChanged: {
        if (isPluggedIn) {
            if (widthTimer.running)
                widthTimer.stop();
            widthPhase = 1;
            widthTimer.start();
        }
    }

    onIsLowAndNotChargingChanged: {
        if (isLowAndNotCharging) {
            // Optional: use Quickshell.Services.Notifications instead of shell notify-send
            root.sendNotification("Low Battery", "Plug in soon!" /*critical*/ , false);
        }
    }

    onIsCriticalAndNotChargingChanged: {
        if (isCriticalAndNotCharging) {
            root.sendNotification("Critical Battery", "Automatic suspend at 5%!" /*critical*/ , true);
        }
    }

    onIsSuspendingAndNotChargingChanged: {
        if (isSuspendingAndNotCharging) {
            Quickshell.execDetached(["systemctl", "suspend"]);
        }
    }

    // Helper to emit notifications via Quickshell.Services.Notifications (optional)
    function sendNotification(summary, body, critical) {
        var s = String(summary === undefined ? "" : summary);
        var b = String(body === undefined ? "" : body);
        var qml = 'import Quickshell.Services.Notifications\nNotification { summary: "' + s.replace(/"/g, '\\"') + '"; body: "' + b.replace(/"/g, '\\"') + '"; expireTimeout: 5000; urgency: ' + (critical ? 'NotificationUrgency.Critical' : 'NotificationUrgency.Normal') + '; transient: true }';
        Qt.createQmlObject(qml, root, "BatteryNotification");
    }

    Timer {
        id: widthTimer

        interval: 200
        repeat: true
        onTriggered: {
            if (root.widthPhase < 4) {
                root.widthPhase++;
            } else {
                root.widthPhase = 0;
                stop();
            }
        }
    }

    Rectangle {
        id: container

        anchors.fill: parent
        color: Theme.inactiveColor
        radius: height / 2
    }

    Item {
        anchors.fill: container

        ClippingRectangle {
            id: waterClip
            anchors.fill: parent
            radius: waterClip.height / 2
            color: "transparent"

            // Mirror previous Canvas properties for width pulse and color
            property real fullWidth: waterClip.width * root.percentage
            property int widthPhase: root.widthPhase
            property real drawWidth: widthPhase > 0 ? ((widthPhase % 2 === 1) ? 0 : fullWidth) : fullWidth
            property color waterColor: root.percentage <= 0.1 ? "#f38ba8" : root.percentage <= 0.2 ? "#fab387" : Theme.activeColor

            Rectangle {
                id: waterFill
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: waterClip.drawWidth
                color: waterClip.waterColor

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    MouseArea {
        id: batteryArea

        property string remainingTimeText: {
            if (root.device.state === UPowerDeviceState.FullyCharged)
                return "Fully Charged";

            if (root.isCharging && root.device.timeToFull > 0)
                return "Time to full: " + fmt(root.device.timeToFull);

            if (root.device.state === UPowerDeviceState.PendingCharge)
                return "Charge Limit Reached";

            if (!root.isCharging && root.device.isOnline && Math.round(root.percentage * 100) === 100)
                return "Connected";

            if (!root.isCharging && root.device.timeToEmpty > 0)
                return "Time remaining: " + fmt(root.device.timeToEmpty);

            return "Calculating…";
        }

        function fmt(s) {
            if (s <= 0)
                return "Calculating…";

            var h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
            return h > 0 ? h + "h " + m + "m" : m + "m";
        }

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (DetectEnv.batteryManager === "ppd") {
                // Toggle using Quickshell.Services.UPower PowerProfiles (singleton)
                var canPerf = PowerProfiles.hasPerformanceProfile;
                var current = PowerProfiles.profile;
                // Prefer the original behavior: toggle Performance <-> PowerSaver
                if (current === PowerProfile.Performance) {
                    PowerProfiles.profile = PowerProfile.PowerSaver;
                } else {
                    PowerProfiles.profile = canPerf ? PowerProfile.Performance : PowerProfile.PowerSaver;
                }
                PowerMgmt.refreshPowerInfo();
            }

            if (overlayFadeTimer.running)
                overlayFadeTimer.stop();

            if (overlayFlashStartTimer.running)
                overlayFlashStartTimer.stop();

            overlayFlash.opacity = 0;
            root.overlayFlashWidth = 2;
            root.overlayFlashX = root.implicitWidth / 2 - root.overlayFlashWidth / 2;
            overlayFlashStartTimer.start();
        }

        Rectangle {
            anchors.fill: parent
            color: batteryArea.containsMouse ? Theme.onHoverColor : "transparent"
            radius: height / 2

            Behavior on color {
                ColorAnimation {
                    duration: 100
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            id: overlayFlash

            y: 0
            width: root.overlayFlashWidth
            height: parent.height
            x: root.overlayFlashX
            color: "#ffe066"
            radius: height / 2
            opacity: root.overlayFlashWidth > 2 ? 1 : 0

            Behavior on width {
                NumberAnimation {
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        Timer {
            id: overlayFadeTimer

            interval: 600
            repeat: false
            onTriggered: {
                overlayFlash.opacity = 0;
                root.overlayFlashWidth = 2;
                root.overlayFlashX = root.implicitWidth / 2 - root.overlayFlashWidth / 2;
            }
        }

        Timer {
            id: overlayFlashStartTimer

            interval: 20
            repeat: false
            onTriggered: {
                overlayFlash.opacity = 1;
                root.overlayFlashWidth = root.implicitWidth;
                root.overlayFlashX = 0;
                overlayFadeTimer.start();
            }
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 4

            Text {
                id: icon
                text: root.batteryIcon
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                font.bold: true
                color: Theme.textContrast(root.percentage > 0.6 ? (root.percentage <= 0.1 ? "#f38ba8" : root.percentage <= 0.2 ? "#fab387" : Theme.activeColor) : Theme.inactiveColor)
            }

            Text {
                id: percentText

                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(root.percentage * 100) + "%"
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                font.bold: true
                color: Theme.textContrast(root.percentage > 0.6 ? (root.percentage <= 0.1 ? "#f38ba8" : root.percentage <= 0.2 ? "#fab387" : Theme.activeColor) : Theme.inactiveColor)
            }
        }

        Rectangle {
            id: tooltip

            visible: batteryArea.containsMouse
            color: Theme.onHoverColor
            radius: Theme.itemRadius
            width: tooltipColumn.width + 16
            height: tooltipColumn.height + 8
            anchors.top: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 8
            opacity: batteryArea.containsMouse ? 1 : 0

            Column {
                id: tooltipColumn

                anchors.centerIn: parent
                spacing: 4

                Text {
                    id: tooltipText

                    text: qsTr("%1").arg(batteryArea.remainingTimeText)
                    color: Theme.textContrast(Theme.onHoverColor)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                }

                Text {
                    id: placeholderText

                    text: DetectEnv.batteryManager === "ppd" ? (PowerMgmt.ppdText && PowerMgmt.ppdText.length > 0 ? qsTr("PPD: %1").arg(PowerMgmt.ppdText) : PowerMgmt.ppdInfo) : (PowerMgmt.platformProfile && PowerMgmt.platformProfile.length > 0 ? qsTr("Platform: %1").arg(PowerMgmt.platformProfile) : PowerMgmt.platformInfo)
                    color: Theme.textContrast(Theme.onHoverColor)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                    opacity: 0.7
                }

                Text {
                    id: thermalText

                    text: qsTr("CPU: %1 + %2").arg(PowerMgmt.cpuGovernor || qsTr("Unknown")).arg(PowerMgmt.energyPerformance || qsTr("Unknown"))
                    color: Theme.textContrast(Theme.onHoverColor)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                    opacity: 0.6
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animationDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
