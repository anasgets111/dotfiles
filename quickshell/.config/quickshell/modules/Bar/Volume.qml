pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Widgets

Rectangle {
    id: volumeControl
    clip: true

    property real __wheelAccum: 0

    property int padding: 10
    property real stepSize: 0.05               // 5% per tick
    property int sliderSteps: 20               // snapping steps in slider
    property real maxVolume: 1.0               // allow >1.0 to support overamplification
    property bool preserveChannelBalance: false // scale channels vs. uniform write

    property int expandedWidth: 220
    property real collapsedWidth: volumeIconItem.implicitWidth + 2 * padding
    property var deviceIconMap: {
        "headphone": "󰋋",
        "hands-free": "󰋎",
        "headset": "󰋎",
        "phone": "󰏲",
        "portable": "󰏲"
    }
    property string deviceIcon: {
        if (!serviceSink)
            return "";
        var iconName = serviceSink.properties ? serviceSink.properties["device.icon_name"] : "";
        if (iconName && deviceIconMap[iconName])
            return deviceIconMap[iconName];
        var desc = (serviceSink.description || "").toLowerCase();
        for (var key in deviceIconMap) {
            if (desc.indexOf(key) !== -1)
                return deviceIconMap[key];
        }
        if ((serviceSink.name || "").startsWith("bluez_output"))
            return deviceIconMap["headphone"];
        return "";
    }
    property string volumeIcon: {
        var ratio = maxVolume > 0 ? (volume / maxVolume) : 0;
        var icon = audioReady ? (deviceIcon || (muted ? "󰝟" : ratio < 0.01 ? "󰖁" : ratio < 0.33 ? "󰕿" : ratio < 0.66 ? "󰖀" : "󰕾")) : "--";
        return icon;
    }

    width: collapsedWidth
    height: Theme.itemHeight
    radius: Theme.itemRadius
    color: Theme.inactiveColor

    property bool suppressFillAnim: false
    Timer {
        id: hoverTransitionTimer
        interval: Theme.animationDuration
        repeat: false
        running: false
        onTriggered: volumeControl.suppressFillAnim = false
    }

    readonly property color contrastColor: {
        var leftColor = Theme.activeColor;
        var bgColor = volumeControl.color;
        if (volumeControl.width === volumeControl.collapsedWidth) {
            return Theme.textContrast(bgColor);
        }
        var useColor = sliderBg.sliderValue > 0.5 ? leftColor : bgColor;
        return Theme.textContrast(Qt.colorEqual(useColor, "transparent") ? bgColor : useColor);
    }

    states: [
        State {
            name: "hovered"
            when: rootArea.containsMouse
            PropertyChanges {
                volumeControl.width: expandedWidth
            }
        }
    ]

    MouseArea {
        id: rootArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onContainsMouseChanged: function () {
            volumeControl.suppressFillAnim = true;
            hoverTransitionTimer.restart();
        }

        onClicked: function (event) {
            if (!volumeControl.audioReady)
                return;
            if (event.button === Qt.MiddleButton) {
                volumeControl.muted = !volumeControl.muted;
                volumeControl.serviceSink.audio.muted = volumeControl.muted;
            }
        }

        onWheel: function (wheelEvent) {
            if (!volumeControl.audioReady)
                return;

            var eff = (wheelEvent.pixelDelta && wheelEvent.pixelDelta.y) ? wheelEvent.pixelDelta.y : wheelEvent.angleDelta.y;
            if (!eff || Math.abs(eff) < 1) {
                wheelEvent.accepted = true;
                return;
            }

            var unit = 50.0;
            volumeControl.__wheelAccum += eff;
            var whole = Math.trunc(volumeControl.__wheelAccum / unit);
            if (whole === 0) {
                wheelEvent.accepted = true;
                return;
            }
            volumeControl.__wheelAccum -= whole * unit;

            var delta = whole * volumeControl.stepSize * volumeControl.maxVolume;
            var target = volumeControl.volume + delta;
            volumeControl.setVolumeValue(target);
            wheelEvent.accepted = true;
        }
    }

    property PwNode serviceSink: Pipewire.defaultAudioSink
    property real volume: 0.0
    property bool muted: false

    property bool audioReady: {
        Pipewire.ready && serviceSink && serviceSink.audio;
    }

    Component.onCompleted: volumeControl.bindToSink()
    Connections {
        target: Pipewire
        ignoreUnknownSignals: true
        function onReadyChanged() {
            volumeControl.bindToSink();
        }
        function onDefaultAudioSinkChanged() {
            volumeControl.bindToSink();
        }
    }

    function averageVolumeFromAudio(audio) {
        if (!audio)
            return 0.0;
        var v = audio.volume;
        if (typeof v === "number" && !isNaN(v))
            return v;
        if (Array.isArray(audio.volumes)) {
            if (audio.volumes.length === 0)
                return 0.0;
            return audio.volumes.reduce(function (a, x) {
                return a + x;
            }, 0) / audio.volumes.length;
        }
        return 0.0;
    }

    // Centralized volume setter with optional channel balance preservation
    function setVolumeValue(v) {
        if (!volumeControl.audioReady)
            return;
        var clamped = Math.max(0, Math.min(volumeControl.maxVolume, v));
        var writeVal = volumeControl.maxVolume > 0 ? (clamped / volumeControl.maxVolume) : 0.0;
        var audio = volumeControl.serviceSink.audio;
        if (!audio)
            return;
        if (volumeControl.preserveChannelBalance) {
            var chans = audio.volumes || [];
            if (Array.isArray(chans) && chans.length) {
                var oldAvg = volumeControl.averageVolumeFromAudio(audio);
                var ratio = oldAvg > 0 ? (writeVal / oldAvg) : 0;
                var newChans = [];
                for (var i = 0; i < chans.length; ++i) {
                    var nv = Math.max(0, Math.min(1, chans[i] * ratio));
                    newChans.push(nv);
                }
                audio.volumes = newChans;
                audio.volume = newChans.reduce(function (a, x) {
                    return a + x;
                }, 0) / newChans.length;
            } else {
                audio.volume = writeVal;
            }
        } else {
            audio.volume = writeVal;
            var chans2 = audio.volumes || [];
            if (Array.isArray(chans2) && chans2.length)
                audio.volumes = Array(chans2.length).fill(writeVal);
        }
    }

    function bindToSink() {
        volume = 0.0;
        muted = false;
        if (Pipewire.ready)
            serviceSink = Pipewire.defaultAudioSink;
        if (serviceSink && serviceSink.audio) {
            volume = averageVolumeFromAudio(serviceSink.audio);
            muted = !!serviceSink.audio.muted;
        }
    }

    Connections {
        target: volumeControl.serviceSink
        ignoreUnknownSignals: true
        enabled: !!volumeControl.serviceSink
        function onAudioChanged() {
            volumeControl.bindToSink();
        }
    }

    PwObjectTracker {
        id: pwTracker
        objects: volumeControl.serviceSink && volumeControl.serviceSink.audio ? [volumeControl.serviceSink, volumeControl.serviceSink.audio] : (volumeControl.serviceSink ? [volumeControl.serviceSink] : [])
    }

    Connections {
        id: audioConnections
        target: volumeControl.serviceSink && volumeControl.serviceSink.audio ? volumeControl.serviceSink.audio : null
        ignoreUnknownSignals: true
        enabled: !!(volumeControl.serviceSink && volumeControl.serviceSink.audio)
        function onVolumeChanged() {
            volumeControl.volume = volumeControl.averageVolumeFromAudio(volumeControl.serviceSink.audio);
            sliderBg.committing = false;
        }
        function onMutedChanged() {
            volumeControl.muted = volumeControl.serviceSink.audio.muted;
        }
    }

    Item {
        id: sliderBg
        anchors.fill: parent
        property bool dragging: false
        property bool committing: false
        property real pendingValue: (volumeControl.maxVolume > 0 ? (volumeControl.volume / volumeControl.maxVolume) : 0)
        property real sliderValue: (dragging || committing) ? pendingValue : (volumeControl.maxVolume > 0 ? (volumeControl.volume / volumeControl.maxVolume) : 0)

        ClippingRectangle {
            anchors.fill: parent
            radius: volumeControl.radius
            color: "transparent"
            visible: rootArea.containsMouse || sliderBg.dragging

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * sliderBg.sliderValue
                color: Theme.activeColor

                Behavior on width {
                    NumberAnimation {
                        duration: (sliderBg.dragging || sliderBg.committing || volumeControl.suppressFillAnim) ? 0 : Theme.animationDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onPressed: function (event) {
                sliderBg.dragging = true;
                update(event.x);
            }
            onPositionChanged: function (event) {
                if (!sliderBg.dragging)
                    return;
                update(event.x);
            }
            onReleased: function () {
                // Keep visual at clicked spot until backend confirms
                sliderBg.committing = true;
                sliderBg.dragging = false;
                commitVolume(sliderBg.pendingValue);
            }

            function update(x) {
                var raw = x / parent.width;
                var clampedRaw = Math.min(1, Math.max(0, raw));
                var steps = Math.max(1, volumeControl.sliderSteps);
                var stepped = Math.round(clampedRaw * steps) / steps;
                sliderBg.pendingValue = stepped;
            }
            function commitVolume(v) {
                if (!volumeControl.audioReady)
                    return;
                var steps = Math.max(1, volumeControl.sliderSteps);
                var stepped = Math.round(v * steps) / steps;
                var target = stepped * volumeControl.maxVolume;
                volumeControl.setVolumeValue(target);
            }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8
        anchors.margins: volumeControl.padding

        Text {
            id: maxIconMeasure
            text: "󰕾"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + Theme.fontSize / 2
            font.bold: true
            visible: false
        }

        Text {
            id: maxPercentMeasure
            text: "100%"
            font.pixelSize: Theme.fontSize
            font.family: Theme.fontFamily
            font.bold: true
            visible: false
        }

        Item {
            id: volumeIconItem
            implicitWidth: maxIconMeasure.paintedWidth
            implicitHeight: maxIconMeasure.paintedHeight
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight

            Text {
                anchors.centerIn: parent
                text: volumeControl.volumeIcon
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + Theme.fontSize / 2
                font.bold: true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                color: volumeControl.contrastColor
            }
        }

        Item {
            id: percentageItem
            implicitWidth: maxPercentMeasure.paintedWidth
            implicitHeight: maxPercentMeasure.paintedHeight
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            visible: volumeControl.width > volumeControl.collapsedWidth

            Text {
                anchors.centerIn: parent
                text: volumeControl.audioReady ? (volumeControl.muted ? "0%" : Math.round((volumeControl.volume / volumeControl.maxVolume) * 100) + "%") : "--"
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                font.bold: true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                color: volumeControl.contrastColor
            }
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
        }
    }

    // Accessibility & keyboard controls
    Accessible.role: Accessible.Slider
    Accessible.name: "Volume"
    focus: true
    activeFocusOnTab: true
    Keys.onPressed: function (event) {
        if (!volumeControl.audioReady)
            return;
        if (event.key === Qt.Key_Left) {
            volumeControl.setVolumeValue(volumeControl.volume - volumeControl.stepSize * volumeControl.maxVolume);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            volumeControl.setVolumeValue(volumeControl.volume + volumeControl.stepSize * volumeControl.maxVolume);
            event.accepted = true;
        } else if (event.key === Qt.Key_M) {
            volumeControl.muted = !volumeControl.muted;
            volumeControl.serviceSink.audio.muted = volumeControl.muted;
            event.accepted = true;
        }
    }
}
