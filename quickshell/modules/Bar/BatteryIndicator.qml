import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Io

Item {
    id: root
    implicitHeight: Theme.itemHeight
    implicitWidth: row.implicitWidth + 12

    // UPower state
    property var   device:        UPower.displayDevice
    property real  percentage:    device.percentage
    property bool  isCharging:    device.state === UPowerDeviceState.Charging

    // Low/critical thresholds
    property bool  isLowAndNotCharging:
        device.isLaptopBattery && percentage <= 0.20 && !isCharging
    property bool  isCriticalAndNotCharging:
        device.isLaptopBattery && percentage <= 0.10 && !isCharging
    property bool  isSuspendingAndNotCharging:
        device.isLaptopBattery && percentage <= 0.05 && !isCharging

    // ——————————————————————————————————————————
    // FLASH PHASES
    // ——————————————————————————————————————————

    // widthPhase pulses the fill from 0→fullWidth→0→fullWidth
    property int   widthPhase: 0
    Timer {
        id: widthTimer; interval: 200; repeat: true
        onTriggered: {
            if (widthPhase < 4) widthPhase++
            else { widthPhase = 0; stop() }
        }
    }
    // colorPhase drives the overlay‐color pulse
    property int   colorPhase: 0
    Timer {
        id: colorTimer; interval: 200; repeat: true
        onTriggered: {
            if (colorPhase < 4) colorPhase++
            else { colorPhase = 0; stop() }
        }
    }

    // on charger connect → pulse the fill
    onIsChargingChanged: if (isCharging) {
        widthPhase = 1; widthTimer.start()
    }

    // on click (below) → pulse the overlay
    // ——————————————————————————————————————————
    // NOTIFICATIONS & SUSPEND
    // ——————————————————————————————————————————

    onIsLowAndNotChargingChanged:
        if (isLowAndNotCharging)
            Quickshell.execDetached(
                ["notify-send","Low Battery","Plug in soon!"]
            )
    onIsCriticalAndNotChargingChanged:
        if (isCriticalAndNotCharging)
            Quickshell.execDetached([
                "notify-send","-u","critical",
                "Critical Battery","Automatic suspend at 5%!"
            ])
    onIsSuspendingAndNotChargingChanged:
        if (isSuspendingAndNotCharging)
            Quickshell.execDetached(["systemctl","suspend"])

    // ——————————————————————————————————————————
    // BACKGROUND
    // ——————————————————————————————————————————

    Rectangle {
        anchors.fill: parent
        color: Theme.inactiveColor
        radius: height/2
    }

    // ——————————————————————————————————————————
    // ACTIVE FILL (widthPulse + color based on profile & level)
    // ——————————————————————————————————————————

    Rectangle {
        id: fill
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        property real fullW: parent.width * percentage

        // widthPulse on charger: 0⇄fullW twice
        width: widthPhase > 0
               ? (widthPhase % 2 === 1 ? 0 : fullW)
               : fullW

        radius: height/2
        color: batteryArea.powerProfile === "power-saver"
               ? Theme.powerSaveColor
               : (batteryArea.powerProfile === "performance" || batteryArea.powerProfile === "balanced")
                 ? (percentage <= 0.10 ? "#f38ba8"
                    : percentage <= 0.20 ? "#fab387"
                    : Theme.activeColor)
                 : Theme.activeColor

        Behavior on width {
            NumberAnimation { duration: Theme.animationDuration
                              easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: Theme.animationDuration
                              easing.type: Easing.OutCubic }
        }
    }

    // ——————————————————————————————————————————
    // MOUSEAREA + TOOLTIP + PROFILE FETCH & TOGGLE
    // ——————————————————————————————————————————

    MouseArea {
        id: batteryArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // remaining‐time text
        property string remainingTimeText: {
            function fmt(s) {
                if (s <= 0) return "Calculating…"
                var h = Math.floor(s/3600),
                    m = Math.round((s % 3600)/60)
                return h>0 ? h+"h "+m+"m" : m+"m"
            }
            if (isCharging && device.timeToFull>0)
                return "Time to full: "+fmt(device.timeToFull)
            if (!isCharging && device.timeToEmpty>0)
                return "Time remaining: "+fmt(device.timeToEmpty)
            return "Calculating…"
        }

        // powerProfile property + fetch
        property string powerProfile: ""
        Component.onCompleted: profileProc.running = true
        Process {
            id: profileProc
            command: ["powerprofilesctl","get"]
            running: batteryArea.containsMouse || profileProc.running
            stdout: StdioCollector {
                onStreamFinished: batteryArea.powerProfile = text.trim()
            }
        }
        // toggle to next profile
        Process {
            id: setProc
            stdout: StdioCollector {}
            onExited: profileProc.running = true
        }

        onClicked: {
            var next = batteryArea.powerProfile==="performance"
                       ? "power-saver" : "performance"
            setProc.command = ["powerprofilesctl","set",next]
            setProc.running = true
            // pulse overlay
            colorPhase = 1; colorTimer.start()
        }

        // ——————————————————————————————————
        // FLASH‐OVERLAY (above the fill)
        // ——————————————————————————————————
        Rectangle {
            anchors.fill: parent
            color: (colorPhase===1 || colorPhase===3)
                   ? "#ffe066"
                   : batteryArea.containsMouse
                     ? Theme.onHoverColor
                     : "transparent"
            radius: height/2
            Behavior on color {
                ColorAnimation { duration:100
                                 easing.type: Easing.OutCubic }
            }
        }

        // ——————————————————————————————————
        // ICON + PERCENT
        // ——————————————————————————————————
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 4

            Text {
                id: icon
                text: isCharging ? ""
                      : percentage>0.8 ? ""
                      : percentage>0.6 ? ""
                      : percentage>0.4 ? ""
                      : percentage>0.2 ? ""
                                       : ""
                font.pixelSize: Theme.fontSize
                font.family:    Theme.fontFamily
                font.bold:      true
                color: Theme.textContrast(
                    percentage>0.6
                      ? (percentage<=0.10 ? "#f38ba8"
                        : percentage<=0.20 ? "#fab387"
                        : Theme.activeColor)
                      : Theme.inactiveColor
                )
            }
            Text {
                id: percentText
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(percentage*100)+"%"
                font.pixelSize: Theme.fontSize
                font.family:    Theme.fontFamily
                font.bold:      true
                color: Theme.textContrast(
                    percentage>0.6
                      ? (percentage<=0.10 ? "#f38ba8"
                        : percentage<=0.20 ? "#fab387"
                        : Theme.activeColor)
                      : Theme.inactiveColor
                )
            }
        }

        // ——————————————————————————————————
        // TOOLTIP
        // ——————————————————————————————————
        Rectangle {
            id: tooltip
            visible: batteryArea.containsMouse
            color:   Theme.onHoverColor
            radius:  Theme.itemRadius
            width:   tooltipColumn.width + 16
            height:  tooltipColumn.height + 8
            anchors.top:              parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin:        8
            opacity: batteryArea.containsMouse ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.animationDuration
                                  easing.type: Easing.OutCubic }
            }

            Column {
                id: tooltipColumn
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text: batteryArea.remainingTimeText
                    color: Theme.textContrast(Theme.onHoverColor)
                    font.pixelSize: Theme.fontSize
                    font.family:    Theme.fontFamily
                }
                Text {
                    visible: batteryArea.powerProfile.length > 0
                    text:    "Profile: " + batteryArea.powerProfile
                    color:   Theme.textContrast(Theme.onHoverColor)
                    font.pixelSize: Theme.fontSize - 2
                    font.family:    Theme.fontFamily
                }
            }
        }
    }
}
