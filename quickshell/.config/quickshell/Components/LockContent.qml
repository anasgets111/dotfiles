pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Services.Utils
import qs.Services
import qs.Services.SystemInfo
import qs.Services.WM

// Extracted lock screen content panel
FocusScope {
    id: panel

    // Inputs from parent
    required property var ctx         // parent scope/root providing theme, authState, passwordBuffer
    required property var lockSurface // WlSessionLockSurface instance
    required property var pamAuth     // PamContext instance

    anchors.centerIn: parent
    width: parent.width * 0.47
    height: column.implicitHeight + 32
    visible: lockSurface && lockSurface.hasScreen
    opacity: lockSurface && lockSurface.hasScreen ? 1 : 0
    scale: lockSurface && lockSurface.hasScreen ? 1 : 0.98
    property color accent: ctx && ctx.theme ? ctx.theme.mauve : "#cba6f7"
    // compact mode for smaller widths to avoid pill overflow
    property bool compact: width < 440
    // vertical padding for info pills
    property int pillPadV: compact ? 6 : 8

    function shake() {
        shakeAnim.restart();
    }

    // Fallback focus policy: if the snapshot primary monitor is absent (e.g., DPMS off
    // or hotplug during lock), allow one-time focus on the last currently available
    // monitor, then naturally reassert focus to the snapshot primary once it returns.
    readonly property string _snapshotPrimaryName: (ctx && ctx.snapshotMonitorNames && ctx.snapshotMonitorNames.length) ? ctx.snapshotMonitorNames[ctx.snapshotMonitorNames.length - 1] : ""
    function _currentMonitorNames() {
        try {
            return ctx && ctx.currentMonitorNames ? ctx.currentMonitorNames() : [];
        } catch (e) {
            return [];
        }
    }
    function _maybeRequestFocusOnce(reason) {
        if (!lockSurface || !lockSurface.hasScreen)
            return;
        const isPrimary = lockSurface.isMainMonitor;
        if (isPrimary) {
            panel.forceActiveFocus();
            if (panel.ctx) {
                Logger.log("LockContent", "single-shot focus request (primary): " + reason);
            }
        }
    }

    Component.onCompleted: {
        // Single-shot attempt at startup
        _maybeRequestFocusOnce("component completed");
    }
    Connections {
        target: panel.lockSurface
        function onHasScreenChanged() {
            if (!panel.lockSurface)
                return;
            if (panel.lockSurface.hasScreen)
                panel._maybeRequestFocusOnce("hasScreen changed -> true");
        }
    }

    transform: Translate {
        id: panelShake
        x: 0
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: shakeAnim
        running: false
        NumberAnimation {
            target: panelShake
            property: "x"
            from: 0
            to: 10
            duration: 40
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panelShake
            property: "x"
            from: 10
            to: -10
            duration: 70
        }
        NumberAnimation {
            target: panelShake
            property: "x"
            from: -10
            to: 6
            duration: 60
        }
        NumberAnimation {
            target: panelShake
            property: "x"
            from: 6
            to: -4
            duration: 50
        }
        NumberAnimation {
            target: panelShake
            property: "x"
            from: -4
            to: 0
            duration: 40
        }
    }

    Connections {
        target: panel.ctx
        function onAuthStateChanged() {
            if (panel.ctx.authState === "error" || panel.ctx.authState === "fail")
                panel.shake();
        }
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.35)
        shadowBlur: 0.9
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 10
        blurEnabled: false
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        border.width: 1
        border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.20)
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.70)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(24 / 255, 24 / 255, 37 / 255, 0.66)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        border.width: 1
        border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.08)
        color: "transparent"
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Text {
                text: Qt.formatTime(TimeService.currentDate, "HH:mm")
                color: panel.ctx.theme.text
                font.pixelSize: 74
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: Qt.formatTime(TimeService.currentDate, "AP")
                visible: text !== ""
                color: panel.ctx.theme.subtext1
                font.pixelSize: 30
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDate(TimeService.currentDate, "dddd, d MMMM yyyy")
            color: panel.ctx.theme.subtext0
            font.pixelSize: 21
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: panel.width - 64
        }

        // Identity
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: MainService.fullName ? MainService.fullName : ""
            visible: panel.lockSurface.hasScreen && text.length > 0
            color: panel.ctx.theme.subtext1
            font.pixelSize: 24
            font.bold: true
            elide: Text.ElideRight
            Layout.preferredWidth: panel.width - 64
            Layout.topMargin: 2
            horizontalAlignment: Text.AlignHCenter
        }

        // Info pills row (weather, host)
        RowLayout {
            id: pillsRow
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Layout.preferredWidth: panel.width - 64
            visible: panel.lockSurface.hasScreen
            // Shared height so both pills match visually
            // Weather pill may wrap location into its own line; account for that height.
            property int hostLineHeight: Math.max(hostIcon.font.pixelSize, hostText.font.pixelSize)
            property int pillHeight: Math.max(hostLineHeight, wxPill.contentHeight) + panel.pillPadV * 2

            // Weather pill
            Rectangle {
                id: wxPill
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                Layout.maximumWidth: Math.floor((panel.width - 64 - pillsRow.spacing) / 2)
                Layout.preferredHeight: pillsRow.pillHeight
                radius: 10
                color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
                border.width: 1
                border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
                visible: panel.lockSurface.hasScreen && WeatherService
                opacity: visible ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }
                // Expose computed content height for pillsRow
                property int contentHeight: wxCol.contentHeight

                // Content with optional wrapping of location to a new line
                ColumnLayout {
                    id: wxCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: panel.compact ? 8 : 10
                    spacing: 2

                    // Weather data
                    property string icon: WeatherService ? WeatherService.getWeatherIconFromCode() : ""
                    property string temp: WeatherService ? WeatherService.currentTemp : ""
                    property string place: WeatherService && WeatherService.locationName ? WeatherService.locationName : ""
                    property bool stale: WeatherService ? WeatherService.isStale : false

                    // Whether location fits inline alongside icon/temp/stale
                    // Computed against the actual available width of this column
                    readonly property bool fitsInline: (wxIcon.implicitWidth + topRow.spacing + wxTemp.implicitWidth + (wxCol.place.length > 0 ? topRow.spacing + wxPlaceInline.implicitWidth : 0) + (wxCol.stale ? topRow.spacing + staleBadge.implicitWidth : 0)) <= wxCol.width

                    // Effective content height for pill height calculation
                    // Single-line when fitsInline; two lines when wrapped
                    readonly property int contentHeight: fitsInline ? Math.max(wxIcon.font.pixelSize, wxTemp.font.pixelSize, wxPlaceInline.font.pixelSize) : Math.max(wxIcon.font.pixelSize, wxTemp.font.pixelSize) + wxCol.spacing + (wxPlace.visible ? wxPlace.font.pixelSize : 0)

                    RowLayout {
                        id: topRow
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            id: wxIcon
                            Layout.alignment: Qt.AlignVCenter
                            text: wxCol.icon
                            color: panel.ctx.theme.text
                            font.pixelSize: 27
                        }
                        Text {
                            id: wxTemp
                            Layout.alignment: Qt.AlignVCenter
                            text: WeatherService ? Math.max(0, wxCol.temp.indexOf("°")) >= 0 ? wxCol.temp.split(" ")[0] : wxCol.temp : ""
                            color: panel.ctx.theme.text
                            font.pixelSize: 21
                            font.bold: true
                        }

                        // Inline location (only when it fits)
                        Text {
                            id: wxPlaceInline
                            Layout.alignment: Qt.AlignVCenter
                            text: wxCol.place
                            visible: !panel.compact && text.length > 0 && wxCol.fitsInline
                            color: panel.ctx.theme.subtext0
                            font.pixelSize: 16
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            id: staleBadge
                            Layout.alignment: Qt.AlignVCenter
                            visible: wxCol.stale
                            radius: 6
                            color: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 0.36)
                            implicitHeight: 18
                            implicitWidth: staleText.implicitWidth + 10
                            Text {
                                id: staleText
                                anchors.centerIn: parent
                                text: "stale"
                                color: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 1.0)
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }
                    }

                    // Wrapped location (shown on its own line when not fitting inline)
                    Text {
                        id: wxPlace
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        text: wxCol.place
                        visible: !panel.compact && text.length > 0 && !wxCol.fitsInline
                        color: panel.ctx.theme.subtext0
                        font.pixelSize: 16
                        elide: Text.ElideRight
                    }
                }
            }

            // Host pill
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                Layout.maximumWidth: Math.floor((panel.width - 64 - pillsRow.spacing) / 2)
                Layout.preferredHeight: pillsRow.pillHeight
                radius: 10
                color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
                border.width: 1
                border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
                // Keep host pill visible when the lock surface is present, even if hostname is temporarily unavailable
                visible: panel.lockSurface.hasScreen
                opacity: visible ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                RowLayout {
                    id: hostRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: panel.compact ? 8 : 10
                    spacing: 8
                    Text {
                        id: hostIcon
                        Layout.alignment: Qt.AlignVCenter
                        text: "💻"
                        color: panel.ctx.theme.text
                        font.pixelSize: 21
                    }
                    Text {
                        id: hostText
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        // Safe fallback when hostname is empty or not yet populated
                        text: (MainService && typeof MainService.hostname === "string" && MainService.hostname.length > 0) ? MainService.hostname : "localhost"
                        color: panel.ctx.theme.subtext0
                        font.pixelSize: 21
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Soft divider before password (primary only)
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            visible: panel.lockSurface.isMainMonitor
            Layout.preferredWidth: Math.min(panel.width - 64, 420)
            Layout.preferredHeight: 1
            radius: 1
            color: Qt.rgba(124 / 255, 124 / 255, 148 / 255, 0.25)
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(panel.width - 32, 440)
            Layout.preferredHeight: 46
            radius: 12
            color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.45)
            border.width: 1
            border.color: panel.ctx.authState ? panel.ctx.theme.love : Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.18)
            visible: panel.lockSurface.isMainMonitor
            enabled: panel.lockSurface.hasScreen && panel.lockSurface.isMainMonitor

            // Left lock icon
            Text {
                id: lockIcon
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 14
                text: "🔒"
                color: panel.ctx.theme.overlay1
                font.pixelSize: 21
                opacity: 0.9
            }

            // Symmetric content area
            Item {
                id: passContent
                anchors.fill: parent
                anchors.leftMargin: lockIcon.anchors.leftMargin + lockIcon.width + 8
                anchors.rightMargin: anchors.leftMargin
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 2
                border.color: panel.accent
                // Use panel.activeFocus rather than local focus, since key handling now lives at the panel level
                opacity: panel.activeFocus ? 0.55 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }
            }
            // Key handling moved to panel-level FocusScope

            Row {
                anchors.centerIn: passContent
                spacing: 7
                Repeater {
                    model: panel.ctx.passwordBuffer.length
                    delegate: Rectangle {
                        implicitWidth: 10
                        implicitHeight: 10
                        radius: 5
                        color: panel.pamAuth.active ? panel.ctx.theme.mauve : panel.ctx.theme.overlay2
                        scale: 0.8
                        SequentialAnimation on opacity {
                            loops: 1
                            running: true
                            NumberAnimation {
                                from: 0
                                to: 1
                                duration: 90
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 90
                                easing.type: Easing.OutCubic
                            }
                        }
                        Component.onCompleted: scale = 1.0
                    }
                }
            }

            Text {
                anchors.centerIn: passContent
                text: panel.pamAuth.active ? "Authenticating…" : panel.ctx.authState === "error" ? "Error" : panel.ctx.authState === "max" ? "Too many tries" : panel.ctx.authState === "fail" ? "Incorrect password" : panel.ctx.passwordBuffer.length ? "" : "Enter password"
                color: panel.pamAuth.active ? panel.accent : panel.ctx.authState ? panel.ctx.theme.love : panel.ctx.theme.overlay1
                font.pixelSize: 21
                opacity: panel.ctx.passwordBuffer.length ? 0 : 1
                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            opacity: 0.9
            visible: panel.lockSurface.isMainMonitor
            Text {
                text: "Press Enter to unlock"
                color: panel.ctx.theme.overlay1
                font.pixelSize: 16
            }
            Rectangle {
                implicitWidth: 4
                implicitHeight: 4
                radius: 2
                color: panel.ctx.theme.overlay0
            }
            Text {
                text: "Esc clears input"
                color: panel.ctx.theme.overlay1
                font.pixelSize: 16
            }
            // Keyboard layout indicator
            Rectangle {
                id: layoutIndicator
                visible: (KeyboardLayoutService.currentLayout.length > 0)
                color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
                border.width: 1
                border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
                radius: 8
                implicitHeight: layoutText.height + 7
                implicitWidth: layoutText.width + 12

                Text {
                    id: layoutText
                    text: KeyboardLayoutService.currentLayout
                    color: panel.ctx.theme.overlay1
                    font.pixelSize: 14
                    anchors.verticalCenter: layoutIndicator.verticalCenter
                    anchors.horizontalCenter: layoutIndicator.horizontalCenter
                }
            }
        }
    }

    // Panel-level key handling so whichever lock surface the compositor focuses can accept input immediately.
    Keys.onPressed: event => {
        if (!panel.lockSurface || !panel.lockSurface.hasScreen)
            return;
        if (panel.pamAuth.active)
            return;
        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            panel.pamAuth.start();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace) {
            panel.ctx.passwordBuffer = event.modifiers & Qt.ControlModifier ? "" : panel.ctx.passwordBuffer.slice(0, -1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            panel.ctx.passwordBuffer = "";
            event.accepted = true;
        } else if (event.text && event.text.length === 1) {
            const t = event.text;
            const c = t.charCodeAt(0);
            if (c >= 0x20 && c <= 0x7E) {
                panel.ctx.passwordBuffer += t;
                event.accepted = true;
            }
        }
    }
}
