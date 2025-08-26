pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Services.Utils
import qs.Services
import qs.Services.SystemInfo
import qs.Services.WM

FocusScope {
    id: lockPanel

    required property var lockContext
    required property var lockSurface
    property color accent: lockContext && lockContext.theme ? lockContext.theme.mauve : "#cba6f7"
    property bool compact: width < 440
    property int pillPadV: compact ? 6 : 8

    anchors.centerIn: parent
    width: parent.width * 0.47
    height: column.implicitHeight + 32
    visible: lockSurface && lockSurface.hasScreen
    opacity: lockSurface && lockSurface.hasScreen ? 1 : 0
    scale: lockSurface && lockSurface.hasScreen ? 1 : 0.98

    function shake() {
        shakeAnim.restart();
    }

    function _maybeRequestFocusOnce(reason) {
        if (!lockSurface || !lockSurface.hasScreen)
            return;
        const isPrimary = lockSurface.isMainMonitor;
        if (isPrimary) {
            lockPanel.forceActiveFocus();
            if (lockPanel.lockContext) {
                Logger.log("LockContent", "single-shot focus request (primary): " + reason);
            }
        }
    }

    Component.onCompleted: {
        _maybeRequestFocusOnce("component completed");
    }
    Connections {
        target: lockPanel.lockSurface
        function onHasScreenChanged() {
            if (!lockPanel.lockSurface)
                return;
            if (lockPanel.lockSurface.hasScreen)
                lockPanel._maybeRequestFocusOnce("hasScreen changed -> true");
        }
    }

    transform: Translate {
        id: lockPanelShake
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
            target: lockPanelShake
            property: "x"
            from: 0
            to: 10
            duration: 40
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: lockPanelShake
            property: "x"
            from: 10
            to: -10
            duration: 70
        }
        NumberAnimation {
            target: lockPanelShake
            property: "x"
            from: -10
            to: 6
            duration: 60
        }
        NumberAnimation {
            target: lockPanelShake
            property: "x"
            from: 6
            to: -4
            duration: 50
        }
        NumberAnimation {
            target: lockPanelShake
            property: "x"
            from: -4
            to: 0
            duration: 40
        }
    }

    Connections {
        target: lockPanel.lockContext
        function onAuthStateChanged() {
            if (lockPanel.lockContext.authState === "error" || lockPanel.lockContext.authState === "fail")
                lockPanel.shake();
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
                color: lockPanel.lockContext.theme.text
                font.pixelSize: 74
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: Qt.formatTime(TimeService.currentDate, "AP")
                visible: text !== ""
                color: lockPanel.lockContext.theme.subtext1
                font.pixelSize: 30
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDate(TimeService.currentDate, "dddd, d MMMM yyyy")
            color: lockPanel.lockContext.theme.subtext0
            font.pixelSize: 21
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: lockPanel.width - 64
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: MainService.fullName ? MainService.fullName : ""
            visible: lockPanel.lockSurface.hasScreen && text.length > 0
            color: lockPanel.lockContext.theme.subtext1
            font.pixelSize: 24
            font.bold: true
            elide: Text.ElideRight
            Layout.preferredWidth: lockPanel.width - 64
            Layout.topMargin: 2
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            id: infoPillsRow
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Layout.preferredWidth: lockPanel.width - 64
            visible: lockPanel.lockSurface.hasScreen
            property int hostLineHeight: Math.max(hostIcon.font.pixelSize, hostText.font.pixelSize)
            property int pillHeight: Math.max(hostLineHeight, weatherPill.contentHeight) + lockPanel.pillPadV * 2

            Rectangle {
                id: weatherPill
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                Layout.maximumWidth: Math.floor((lockPanel.width - 64 - infoPillsRow.spacing) / 2)
                Layout.preferredHeight: infoPillsRow.pillHeight
                radius: 10
                color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
                border.width: 1
                border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
                visible: lockPanel.lockSurface.hasScreen && WeatherService
                opacity: visible ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }
                property int contentHeight: weatherColumn.contentHeight

                ColumnLayout {
                    id: weatherColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: lockPanel.compact ? 8 : 10
                    spacing: 2

                    property string icon: WeatherService ? WeatherService.getWeatherIconFromCode() : ""
                    property string temp: WeatherService ? WeatherService.currentTemp : ""
                    property string place: WeatherService && WeatherService.locationName ? WeatherService.locationName : ""
                    property bool stale: WeatherService ? WeatherService.isStale : false

                    readonly property bool fitsInline: (weatherIcon.implicitWidth + weatherTopRow.spacing + weatherTemp.implicitWidth + (weatherColumn.place.length > 0 ? weatherTopRow.spacing + weatherPlaceInline.implicitWidth : 0) + (weatherColumn.stale ? weatherTopRow.spacing + weatherStaleBadge.implicitWidth : 0)) <= weatherColumn.width

                    readonly property int contentHeight: fitsInline ? Math.max(weatherIcon.font.pixelSize, weatherTemp.font.pixelSize, weatherPlaceInline.font.pixelSize) : Math.max(weatherIcon.font.pixelSize, weatherTemp.font.pixelSize) + weatherColumn.spacing + (weatherPlace.visible ? weatherPlace.font.pixelSize : 0)

                    RowLayout {
                        id: weatherTopRow
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            id: weatherIcon
                            Layout.alignment: Qt.AlignVCenter
                            text: weatherColumn.icon
                            color: lockPanel.lockContext.theme.text
                            font.pixelSize: 27
                        }
                        Text {
                            id: weatherTemp
                            Layout.alignment: Qt.AlignVCenter
                            text: WeatherService ? Math.max(0, weatherColumn.temp.indexOf("°")) >= 0 ? weatherColumn.temp.split(" ")[0] : weatherColumn.temp : ""
                            color: lockPanel.lockContext.theme.text
                            font.pixelSize: 21
                            font.bold: true
                        }

                        Text {
                            id: weatherPlaceInline
                            Layout.alignment: Qt.AlignVCenter
                            text: weatherColumn.place
                            visible: !lockPanel.compact && text.length > 0 && weatherColumn.fitsInline
                            color: lockPanel.lockContext.theme.subtext0
                            font.pixelSize: 16
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            id: weatherStaleBadge
                            Layout.alignment: Qt.AlignVCenter
                            visible: weatherColumn.stale
                            radius: 6
                            color: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 0.36)
                            implicitHeight: 18
                            implicitWidth: weatherStaleText.implicitWidth + 10
                            Text {
                                id: weatherStaleText
                                anchors.centerIn: parent
                                text: "stale"
                                color: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 1.0)
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }
                    }

                    Text {
                        id: weatherPlace
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        text: weatherColumn.place
                        visible: !lockPanel.compact && text.length > 0 && !weatherColumn.fitsInline
                        color: lockPanel.lockContext.theme.subtext0
                        font.pixelSize: 16
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                Layout.maximumWidth: Math.floor((lockPanel.width - 64 - infoPillsRow.spacing) / 2)
                Layout.preferredHeight: infoPillsRow.pillHeight
                radius: 10
                color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
                border.width: 1
                border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
                visible: lockPanel.lockSurface.hasScreen
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
                    anchors.margins: lockPanel.compact ? 8 : 10
                    spacing: 8
                    Text {
                        id: hostIcon
                        Layout.alignment: Qt.AlignVCenter
                        text: "💻"
                        color: lockPanel.lockContext.theme.text
                        font.pixelSize: 21
                    }
                    Text {
                        id: hostText
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        text: (MainService && typeof MainService.hostname === "string" && MainService.hostname.length > 0) ? MainService.hostname : "localhost"
                        color: lockPanel.lockContext.theme.subtext0
                        font.pixelSize: 21
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            visible: lockPanel.lockSurface.isMainMonitor
            Layout.preferredWidth: Math.min(lockPanel.width - 64, 420)
            Layout.preferredHeight: 1
            radius: 1
            color: Qt.rgba(124 / 255, 124 / 255, 148 / 255, 0.25)
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(lockPanel.width - 32, 440)
            Layout.preferredHeight: 46
            radius: 12
            color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.45)
            border.width: 1
            border.color: lockPanel.lockContext.authState ? lockPanel.lockContext.theme.love : Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.18)
            visible: lockPanel.lockSurface.isMainMonitor
            enabled: lockPanel.lockSurface.hasScreen && lockPanel.lockSurface.isMainMonitor

            Text {
                id: lockIcon
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 14
                text: "🔒"
                color: lockPanel.lockContext.theme.overlay1
                font.pixelSize: 21
                opacity: 0.9
            }

            Item {
                id: passContent
                anchors.fill: parent
                anchors.leftMargin: lockIcon.anchors.leftMargin + lockIcon.width + 8
                anchors.rightMargin: anchors.leftMargin
            }
            Rectangle {
                id: capsIndicator
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 14
                visible: KeyboardLayoutService.capsOn
                color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
                border.width: 1
                border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
                radius: 8
                implicitHeight: capsText.height + 7
                implicitWidth: capsText.width + 12

                Text {
                    id: capsText
                    anchors.centerIn: parent
                    text: "Caps Lock"
                    color: lockPanel.lockContext.theme.love
                    font.pixelSize: 14
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 2
                border.color: lockPanel.accent
                opacity: lockPanel.activeFocus ? 0.55 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }
            }

            RowLayout {
                anchors.centerIn: passContent
                spacing: 7
                Repeater {
                    model: lockPanel.lockContext.passwordBuffer.length
                    delegate: Rectangle {
                        implicitWidth: 10
                        implicitHeight: 10
                        radius: 5
                        color: lockPanel.lockContext.authenticating ? lockPanel.lockContext.theme.mauve : lockPanel.lockContext.theme.overlay2
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
                text: lockPanel.lockContext.authenticating ? "Authenticating…" : lockPanel.lockContext.authState === "error" ? "Error" : lockPanel.lockContext.authState === "max" ? "Too many tries" : lockPanel.lockContext.authState === "fail" ? "Incorrect password" : lockPanel.lockContext.passwordBuffer.length ? "" : "Enter password"
                color: lockPanel.lockContext.authenticating ? lockPanel.accent : lockPanel.lockContext.authState ? lockPanel.lockContext.theme.love : lockPanel.lockContext.theme.overlay1
                font.pixelSize: 21
                opacity: lockPanel.lockContext.passwordBuffer.length ? 0 : 1
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
            visible: lockPanel.lockSurface.isMainMonitor
            Text {
                text: "Press Enter to unlock"
                color: lockPanel.lockContext.theme.overlay1
                font.pixelSize: 16
            }
            Rectangle {
                implicitWidth: 4
                implicitHeight: 4
                radius: 2
                color: lockPanel.lockContext.theme.overlay0
            }
            Text {
                text: "Esc clears input"
                color: lockPanel.lockContext.theme.overlay1
                font.pixelSize: 16
            }
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
                    color: lockPanel.lockContext.theme.overlay1
                    font.pixelSize: 14
                    anchors.verticalCenter: layoutIndicator.verticalCenter
                    anchors.horizontalCenter: layoutIndicator.horizontalCenter
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (!lockPanel.lockSurface || !lockPanel.lockSurface.hasScreen)
            return;
        if (lockPanel.lockContext.authenticating)
            return;
        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            lockPanel.lockContext.submitOrStart();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace) {
            lockPanel.lockContext.setPasswordBuffer(event.modifiers & Qt.ControlModifier ? "" : lockPanel.lockContext.passwordBuffer.slice(0, -1));
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            lockPanel.lockContext.setPasswordBuffer("");
            event.accepted = true;
        } else if (event.text && event.text.length === 1) {
            const t = event.text;
            const c = t.charCodeAt(0);
            if (c >= 0x20 && c <= 0x7E) {
                lockPanel.lockContext.setPasswordBuffer(lockPanel.lockContext.passwordBuffer + t);
                event.accepted = true;
            }
        }
    }
}
