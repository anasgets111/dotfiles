pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import QtQuick.Effects
import Quickshell.Services.Pam
import qs.Services.Core as Core
import qs.Services.WM as WM
import qs.Services.SystemInfo
import qs.Services as Services

// SystemInfo already imported without alias for TimeService/WeatherService

Scope {
    id: root
    property var logger: LoggerService
    readonly property var theme: ({
            base: "#1e1e2e",
            mantle: "#181825",
            crust: "#11111b",
            surface0: "#313244",
            surface1: "#45475a",
            surface2: "#585b70",
            overlay0: "#6c7086",
            overlay1: "#7f849c",
            overlay2: "#9399b2",
            subtext0: "#a6adc8",
            subtext1: "#bac2de",
            text: "#cdd6f4",
            love: "#f38ba8",
            mauve: "#cba6f7"
        })
    property var snapshotMonitorNames: []
    // Use SystemInfo.TimeService for date/time
    property string passwordBuffer: ""
    property string authState: ""
    function currentMonitorNames() {
        const monitors = WM.MonitorService;
        if (!(monitors && monitors.ready))
            return [];
        const arr = monitors.monitorsModelToArray ? monitors.monitorsModelToArray() : [];
        return arr.map(m => m && m.name).filter(n => !!n);
    }
    Connections {
        target: Core.LockService
        function onLockedChanged() {
            const names = root.currentMonitorNames();
            root.snapshotMonitorNames = Core.LockService.locked ? names : [];
        }
    }

    PamContext {
        id: pamAuth
        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(root.passwordBuffer);
                root.passwordBuffer = "";
                root.logger.log("LockScreen", "PAM response sent; buffer cleared");
            }
        }
        onCompleted: res => {
            if (res === PamResult.Success) {
                root.passwordBuffer = "";
                Core.LockService.locked = false;
                return;
            }
            if (res === PamResult.Error)
                root.authState = "error";
            else if (res === PamResult.MaxTries)
                root.authState = "max";
            else if (res === PamResult.Failed)
                root.authState = "fail";
            authStateResetTimer.restart();
        }
    }
    Timer {
        id: authStateResetTimer
        interval: 1000
        onTriggered: root.authState = ""
    }

    // Pass logger to WeatherService for unified logs
    Component.onCompleted: {
        try {
            if (root.logger && WeatherService) {
                WeatherService.logger = root.logger;
            }
        } catch (e) {}
    }

    WlSessionLock {
        id: sessionLock
        locked: Core.LockService.locked

        WlSessionLockSurface {
            id: lockSurface
            color: "transparent"
            readonly property var screenWallpaper: Core.WallpaperService ? Core.WallpaperService.wallpaperFor(lockSurface.screen) : null
            readonly property bool blurDisabled: Quickshell.env("QS_DISABLE_LOCK_BLUR") === "1"
            readonly property bool hasScreen: !!lockSurface.screen
            readonly property bool isLastMonitorBySnapshot: {
                const s = lockSurface.screen;
                if (!s)
                    return false;
                const names = (root.snapshotMonitorNames && root.snapshotMonitorNames.length) ? root.snapshotMonitorNames : root.currentMonitorNames();
                if (!names || names.length === 0)
                    return true;
                const idx = names.indexOf(s.name);
                return idx >= 0 && idx === names.length - 1;
            }
            Image {
                anchors.fill: parent
                source: Core.WallpaperService && Core.WallpaperService.ready && lockSurface.screenWallpaper && lockSurface.screenWallpaper.wallpaper ? lockSurface.screenWallpaper.wallpaper : ""
                fillMode: {
                    const mode = lockSurface.screenWallpaper ? lockSurface.screenWallpaper.mode : "fill";
                    switch (mode) {
                    case "fill":
                        return Image.PreserveAspectCrop;
                    case "fit":
                        return Image.PreserveAspectFit;
                    case "stretch":
                        return Image.Stretch;
                    case "center":
                        return Image.Pad;
                    case "tile":
                        return Image.Tile;
                    default:
                        return Image.PreserveAspectCrop;
                    }
                }
                visible: lockSurface.hasScreen
                layer.enabled: !lockSurface.blurDisabled
                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 0.75
                    blurMax: 48
                    blurMultiplier: 1
                }
            }
            // one day :D
            // ScreencopyView {
            //     id: background
            //     anchors.fill: parent
            //     captureSource: surface.screen
            //     layer.enabled: true
            //     layer.effect: MultiEffect {
            //         autoPaddingEnabled: false
            //         blurEnabled: true
            //         blur: 0.75
            //         blurMax: 48
            //         blurMultiplier: 1
            //     }
            // }

            Item {
                id: panel
                anchors.centerIn: parent
                width: Math.min(parent.width, 740)
                height: column.implicitHeight + 32
                visible: lockSurface.hasScreen
                opacity: lockSurface.hasScreen ? 1 : 0
                scale: lockSurface.hasScreen ? 1 : 0.98
                property color accent: root.theme.mauve
                // compact mode for smaller widths to avoid pill overflow
                property bool compact: width < 440
                // vertical padding for info pills
                property int pillPadV: compact ? 6 : 8
                function shake() {
                    shakeAnim.restart();
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
                    target: root
                    function onAuthStateChanged() {
                        if (root.authState === "error" || root.authState === "fail")
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
                            color: root.theme.text
                            font.pixelSize: 52
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: Qt.formatTime(TimeService.currentDate, "AP")
                            visible: text !== ""
                            color: root.theme.subtext1
                            font.pixelSize: 22
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDate(TimeService.currentDate, "dddd, d MMMM yyyy")
                        color: root.theme.subtext0
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        Layout.preferredWidth: panel.width - 64
                    }
                    // Identity
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Services.MainService && Services.MainService.fullName ? Services.MainService.fullName : ""
                        visible: lockSurface.hasScreen && text.length > 0
                        color: root.theme.subtext1
                        font.pixelSize: 18
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
                        visible: lockSurface.hasScreen
                        // Weather pill
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            Layout.minimumWidth: 120
                            Layout.maximumWidth: Math.floor((panel.width - 64 - pillsRow.spacing) / 2)
                            Layout.preferredHeight: Math.max(wxIcon.font.pixelSize, wxTemp.font.pixelSize, (!panel.compact && wxPlace.visible ? wxPlace.font.pixelSize : wxTemp.font.pixelSize)) + panel.pillPadV * 2
                            radius: 10
                            color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
                            border.width: 1
                            border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
                            visible: lockSurface.hasScreen && WeatherService
                            opacity: visible ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }
                            RowLayout {
                                id: wxRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: panel.compact ? 8 : 10
                                spacing: 8
                                property string icon: WeatherService ? WeatherService.getWeatherIconFromCode() : ""
                                property string temp: WeatherService ? WeatherService.currentTemp : ""
                                property string place: WeatherService && WeatherService.locationName ? WeatherService.locationName : ""
                                property bool stale: WeatherService ? WeatherService.isStale : false
                                Text {
                                    id: wxIcon
                                    Layout.alignment: Qt.AlignVCenter
                                    text: wxRow.icon
                                    color: root.theme.text
                                    font.pixelSize: 18
                                }
                                Text {
                                    id: wxTemp
                                    Layout.alignment: Qt.AlignVCenter
                                    text: WeatherService ? Math.max(0, wxRow.temp.indexOf("°")) >= 0 ? wxRow.temp.split(" ")[0] : wxRow.temp : ""
                                    color: root.theme.text
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                                // Location text is optional; hide in compact mode
                                Text {
                                    id: wxPlace
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    text: wxRow.place
                                    visible: !panel.compact && text.length > 0
                                    color: root.theme.subtext0
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    // no explicit width; takes remaining space
                                }
                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: wxRow.stale
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
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }
                            }
                        }
                        // Host pill
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            Layout.minimumWidth: 120
                            Layout.maximumWidth: Math.floor((panel.width - 64 - pillsRow.spacing) / 2)
                            Layout.preferredHeight: Math.max(hostIcon.font.pixelSize, hostText.font.pixelSize) + panel.pillPadV * 2
                            radius: 10
                            color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
                            border.width: 1
                            border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
                            visible: Services.MainService && Services.MainService.hostname.length > 0
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
                                    color: root.theme.text
                                    font.pixelSize: 16
                                }
                                Text {
                                    id: hostText
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    text: Services.MainService ? Services.MainService.hostname : ""
                                    color: root.theme.subtext0
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                    // Soft divider before password (primary only)
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        visible: lockSurface.isLastMonitorBySnapshot
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
                        border.color: root.authState ? root.theme.love : Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.18)
                        visible: lockSurface.isLastMonitorBySnapshot
                        enabled: lockSurface.hasScreen && lockSurface.isLastMonitorBySnapshot
                        focus: enabled
                        // Left lock icon for a modern touch
                        Text {
                            id: lockIcon
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            text: "🔒"
                            color: root.theme.overlay1
                            font.pixelSize: 16
                            opacity: 0.9
                        }
                        // Symmetric content area to keep text truly centered despite the left icon
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
                            opacity: parent.focus ? 0.55 : 0.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 160
                                }
                            }
                        }
                        onEnabledChanged: if (enabled)
                            focusDelay.restart()
                        Timer {
                            id: focusDelay
                            interval: 50
                            running: false
                            repeat: false
                            onTriggered: parent.forceActiveFocus()
                        }
                        Keys.onPressed: event => {
                            if (pamAuth.active)
                                return;
                            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                pamAuth.start();
                            } else if (event.key === Qt.Key_Backspace) {
                                root.passwordBuffer = event.modifiers & Qt.ControlModifier ? "" : root.passwordBuffer.slice(0, -1);
                            } else if (event.key === Qt.Key_Escape) {
                                root.passwordBuffer = "";
                            } else if (event.text && event.text.length === 1) {
                                const t = event.text;
                                const c = t.charCodeAt(0);
                                if (c >= 0x20 && c <= 0x7E)
                                    root.passwordBuffer += t;
                            }
                        }
                        Row {
                            anchors.centerIn: passContent
                            spacing: 7
                            Repeater {
                                model: root.passwordBuffer.length
                                delegate: Rectangle {
                                    implicitWidth: 10
                                    implicitHeight: 10
                                    radius: 5
                                    color: pamAuth.active ? root.theme.mauve : root.theme.overlay2
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
                            text: pamAuth.active ? "Authenticating…" : root.authState === "error" ? "Error" : root.authState === "max" ? "Too many tries" : root.authState === "fail" ? "Incorrect password" : root.passwordBuffer.length ? "" : "Enter password"
                            color: pamAuth.active ? panel.accent : root.authState ? root.theme.love : root.theme.overlay1
                            font.pixelSize: 14
                            opacity: root.passwordBuffer.length ? 0 : 1
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
                        visible: lockSurface.isLastMonitorBySnapshot
                        Text {
                            text: "Press Enter to unlock"
                            color: root.theme.overlay1
                            font.pixelSize: 12
                        }
                        Rectangle {
                            implicitWidth: 4
                            implicitHeight: 4
                            radius: 2
                            color: root.theme.overlay0
                        }
                        Text {
                            text: "Esc clears input"
                            color: root.theme.overlay1
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
