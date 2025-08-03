pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

Rectangle {
    id: volumeControl
    clip: true

    property real __wheelAccum: 0

    property int expandedWidth: 220
    property real collapsedWidth: volumeIconItem.implicitWidth + percentageItem.implicitWidth + 2 * 10 + contentRow.spacing

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
        var icon = audioReady ? (deviceIcon || (muted ? "󰝟" : volume < 0.01 ? "󰖁" : volume < 0.33 ? "󰕿" : volume < 0.66 ? "󰖀" : "󰕾")) : "--";
        return icon;
    }

    width: collapsedWidth
    height: Theme.itemHeight
    radius: Theme.itemRadius
    color: Theme.inactiveColor

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

            var delta = whole * 0.05;
            var newVol = Math.max(0, Math.min(1, volumeControl.volume + delta));
            if (newVol >= 0.995)
                newVol = 1.0;
            if (newVol <= 0.005)
                newVol = 0.0;

            if (volumeControl.serviceSink && volumeControl.serviceSink.audio) {
                volumeControl.serviceSink.audio.volume = newVol;
                var chans = volumeControl.serviceSink.audio.volumes || [];
                if (chans.length)
                    volumeControl.serviceSink.audio.volumes = Array(chans.length).fill(newVol);
            }
            wheelEvent.accepted = true;
        }
    }

    property PwNode serviceSink: Pipewire.defaultAudioSink
    property real volume: 0.0
    property bool muted: false

    property bool audioReady: {
        Pipewire.ready && serviceSink?.ready && serviceSink.audio;
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
        }
        function onMutedChanged() {
            volumeControl.muted = volumeControl.serviceSink.audio.muted;
        }
    }

    Item {
        id: sliderBg
        anchors.fill: parent
        property bool dragging: false
        property real pendingValue: volumeControl.volume
        property real sliderValue: dragging ? pendingValue : volumeControl.volume

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * sliderBg.sliderValue
            color: Theme.activeColor
            radius: volumeControl.radius
            visible: rootArea.containsMouse || sliderBg.dragging
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
                sliderBg.dragging = false;
                commitVolume(sliderBg.pendingValue);
            }

            function update(x) {
                var raw = x / parent.width;
                var clampedRaw = Math.min(1, Math.max(0, raw));
                var stepped = Math.round(clampedRaw * 20) / 20;
                sliderBg.pendingValue = stepped;
            }
            function commitVolume(v) {
                if (!volumeControl.audioReady)
                    return;
                var stepped = Math.round(v * 20) / 20;
                volumeControl.serviceSink.audio.volume = stepped;
                var chans = volumeControl.serviceSink.audio.volumes || [];
                if (chans.length)
                    volumeControl.serviceSink.audio.volumes = Array(chans.length).fill(stepped);
            }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8

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

            Text {
                anchors.centerIn: parent
                text: volumeControl.audioReady ? (volumeControl.muted ? "0%" : Math.round(volumeControl.volume * 20) * 5 + "%") : "--"
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
}
