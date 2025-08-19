pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import QtQuick.Effects
import Quickshell.Services.Pam
import qs.Services.Core as Core

Scope {
    id: root
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
    property var screensSnapshotNames: []
    property date now: new Date()
    property string buffer: ""
    property string state: ""
    function screensArray() {
        return Array.prototype.slice.call(Quickshell.screens);
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
    Connections {
        target: Core.LockService
        function onLockedChanged() {
            const names = root.screensArray().map(s => s ? s.name : null).filter(n => !!n);
            root.screensSnapshotNames = Core.LockService.locked ? names : [];
        }
    }

    PamContext {
        id: pam
        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(root.buffer);
                root.buffer = "";
                console.log("[LockScreen] PAM response sent; buffer cleared");
            }
        }
        onCompleted: res => {
            if (res === PamResult.Success) {
                root.buffer = "";
                if (Core.LockService.locked)
                    Core.LockService.locked = false;
                return;
            }
            if (res === PamResult.Error)
                root.state = "error";
            else if (res === PamResult.MaxTries)
                root.state = "max";
            else if (res === PamResult.Failed)
                root.state = "fail";
            stateReset.restart();
        }
    }
    Timer {
        id: stateReset
        interval: 4000
        onTriggered: root.state = ""
    }

    WlSessionLock {
        id: lock
        locked: Core.LockService.locked

        WlSessionLockSurface {
            id: surface
            color: "transparent"
            readonly property var wallpaperEntry: Core.WallpaperService ? Core.WallpaperService.wallpaperFor(surface.screen) : null
            readonly property bool disableBlur: Quickshell.env("QS_DISABLE_LOCK_BLUR") === "0"
            readonly property bool screenReady: surface.screen !== null && surface.screen !== undefined
            readonly property bool isLastScreen: {
                const s = surface.screen;
                if (!s)
                    return false;
                const names = (root.screensSnapshotNames && root.screensSnapshotNames.length) ? root.screensSnapshotNames : root.screensArray().map(x => x ? x.name : null).filter(n => !!n);
                const idx = names.indexOf(s.name);
                return idx >= 0 && idx === names.length - 1;
            }
            Image {
                anchors.fill: parent
                source: Core.WallpaperService && Core.WallpaperService.ready && surface.wallpaperEntry && surface.wallpaperEntry.wallpaper ? surface.wallpaperEntry.wallpaper : ""
                fillMode: {
                    const mode = surface.wallpaperEntry ? surface.wallpaperEntry.mode : "fill";
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
                visible: surface.screenReady
                layer.enabled: true
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
                width: Math.min(parent.width, 560)
                height: column.implicitHeight + 32
                visible: surface.screenReady
                opacity: surface.screenReady ? 1 : 0
                scale: surface.screenReady ? 1 : 0.98
                property color accent: root.theme.mauve
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
                    function onStateChanged() {
                        if (root.state === "error" || root.state === "fail")
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
                            text: Qt.formatTime(root.now, "hh:mm")
                            color: root.theme.text
                            font.pixelSize: 52
                            font.bold: true
                        }
                        Text {
                            text: Qt.formatTime(root.now, "AP")
                            visible: text !== ""
                            color: root.theme.subtext1
                            font.pixelSize: 22
                            font.bold: true
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDate(root.now, "dddd, d MMMM yyyy")
                        color: root.theme.subtext0
                        font.pixelSize: 16
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.min(panel.width - 32, 440)
                        Layout.preferredHeight: 46
                        radius: 12
                        color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.45)
                        border.width: 1
                        border.color: root.state ? root.theme.love : Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.18)
                        visible: surface.isLastScreen
                        enabled: surface.screenReady && surface.isLastScreen
                        focus: enabled
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
                            if (pam.active)
                                return;
                            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                pam.start();
                            } else if (event.key === Qt.Key_Backspace) {
                                root.buffer = event.modifiers & Qt.ControlModifier ? "" : root.buffer.slice(0, -1);
                            } else if (event.key === Qt.Key_Escape) {
                                root.buffer = "";
                            } else if (event.text && event.text.length === 1) {
                                const t = event.text;
                                const c = t.charCodeAt(0);
                                if (c >= 0x20 && c <= 0x7E)
                                    root.buffer += t;
                            }
                        }
                        Row {
                            anchors.centerIn: parent
                            spacing: 7
                            Repeater {
                                model: root.buffer.length
                                delegate: Rectangle {
                                    implicitWidth: 10
                                    implicitHeight: 10
                                    radius: 5
                                    color: pam.active ? root.theme.mauve : root.theme.overlay2
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
                            anchors.centerIn: parent
                            text: pam.active ? "Authenticating…" : root.state === "error" ? "Error" : root.state === "max" ? "Too many tries" : root.state === "fail" ? "Incorrect password" : root.buffer.length ? "" : "Enter password"
                            color: pam.active ? panel.accent : root.state ? root.theme.love : root.theme.overlay1
                            font.pixelSize: 14
                            opacity: root.buffer.length ? 0 : 1
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
