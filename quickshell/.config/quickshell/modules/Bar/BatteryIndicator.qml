pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Item {
    id: root

    property var device: UPower.displayDevice
    property real percentage: device.percentage
    property bool isCharging: device.state === UPowerDeviceState.Charging
    property bool isLowAndNotCharging: DetectEnv.isLaptopBattery && percentage <= 0.2 && !isCharging
    property bool isCriticalAndNotCharging: DetectEnv.isLaptopBattery && percentage <= 0.1 && !isCharging
    property bool isSuspendingAndNotCharging: DetectEnv.isLaptopBattery && percentage <= 0.05 && !isCharging

    property real overlayFlashWidth: 2
    property real overlayFlashX: implicitWidth / 2 - overlayFlashWidth / 2
    property int widthPhase: 0
    property int colorPhase: 0
    property string batteryIcon: {
        if (root.isCharging)
            return "";
        if (root.device.state === UPowerDeviceState.PendingCharge)
            return "󰂄";

        var icons = ["", "", "", "", ""];
        var index = Math.min(Math.floor(root.percentage * 5), 4);
        return icons[index];
    }

    // Process for power profile switching
    Process {
        id: setProc
        command: []
        running: false
    }

    visible: DetectEnv.isLaptopBattery
    implicitHeight: Theme.itemHeight
    implicitWidth: 80

    onIsChargingChanged: {
        if (isCharging) {
            widthPhase = 1;
            widthTimer.start();
        }
    }

    onIsLowAndNotChargingChanged: {
        if (isLowAndNotCharging) {
            Quickshell.execDetached(["notify-send", "Low Battery", "Plug in soon!"]);
        }
    }

    onIsCriticalAndNotChargingChanged: {
        if (isCriticalAndNotCharging) {
            Quickshell.execDetached(["notify-send", "-u", "critical", "Critical Battery", "Automatic suspend at 5%!"]);
        }
    }

    onIsSuspendingAndNotChargingChanged: {
        if (isSuspendingAndNotCharging) {
            Quickshell.execDetached(["systemctl", "suspend"]);
        }
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

    Timer {
        id: colorTimer

        interval: 200
        repeat: true
        onTriggered: {
            if (root.colorPhase < 4) {
                root.colorPhase++;
            } else {
                root.colorPhase = 0;
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

        Canvas {
            id: waterCanvas

            property real fullWidth: width * root.percentage
            property int widthPhase: root.widthPhase
            property real drawWidth: widthPhase > 0 ? ((widthPhase % 2 === 1) ? 0 : fullWidth) : fullWidth
            property color waterColor: root.percentage <= 0.1 ? "#f38ba8" : root.percentage <= 0.2 ? "#fab387" : Theme.activeColor

            anchors.fill: parent
            onDrawWidthChanged: requestPaint()
            onWaterColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var r = height / 2;
                ctx.beginPath();
                ctx.moveTo(r, 0);
                ctx.lineTo(width - r, 0);
                ctx.arc(width - r, r, r, -Math.PI / 2, Math.PI / 2);
                ctx.lineTo(r, height);
                ctx.arc(r, r, r, Math.PI / 2, 3 * Math.PI / 2);
                ctx.closePath();
                ctx.clip();
                ctx.fillStyle = waterColor;
                ctx.fillRect(0, 0, drawWidth, height);
            }

            Behavior on drawWidth {
                NumberAnimation {
                    duration: Theme.animationDuration
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on waterColor {
                ColorAnimation {
                    duration: Theme.animationDuration
                    easing.type: Easing.OutCubic
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
                // PPD: Cycle between power-saver and performance
                var currentProfile = PowerMgmt.ppdInfo.replace("PPD: ", "");
                var next = currentProfile === "performance" ? "power-saver" : "performance";
                setProc.command = ["powerprofilesctl", "set", next];
                setProc.running = true;

                // Refresh immediately - sysfs values update instantly
                PowerMgmt.refreshPowerInfo();
            }

            // Flash animation for both TLP and PPD
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

                    text: batteryArea.remainingTimeText
                    color: Theme.textContrast(Theme.onHoverColor)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                }

                Text {
                    id: placeholderText

                    text: DetectEnv.batteryManager === "ppd" ? PowerMgmt.ppdInfo : PowerMgmt.platformInfo
                    color: Theme.textContrast(Theme.onHoverColor)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                    opacity: 0.7
                }

                Text {
                    id: thermalText

                    text: "CPU: " + PowerMgmt.cpuGovernor + " + " + PowerMgmt.energyPerformance
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
