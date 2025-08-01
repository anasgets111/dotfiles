pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

Rectangle {
    id: volumeControl
    clip: true

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
                target: volumeControl
                width: expandedWidth
            }
        }
    ]

    MouseArea {
        id: rootArea
        anchors.fill: parent
        hoverEnabled: true

        onWheel: function (wheelEvent) {
            if (!audioReady)
                return;
            var step = 0.05;
            var delta = wheelEvent.angleDelta.y > 0 ? step : -step;
            var newVol = Math.max(0, Math.min(1, volume + delta));
            if (serviceSink && serviceSink.audio) {
                serviceSink.audio.volume = newVol;
                var chans = serviceSink.audio.volumes || [];
                if (chans.length)
                    serviceSink.audio.volumes = Array(chans.length).fill(newVol);
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

    Component.onCompleted: bindToSink()
    Connections {
        target: Pipewire
        ignoreUnknownSignals: true
        function onReadyChanged() {
            bindToSink();
        }
        function onDefaultAudioSinkChanged() {
            bindToSink();
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
        if (serviceSink && serviceSink.audio)
            volume = averageVolumeFromAudio(serviceSink.audio);
    }

    PwObjectTracker {
        id: pwTracker
        objects: serviceSink && serviceSink.audio ? [serviceSink, serviceSink.audio] : (serviceSink ? [serviceSink] : [])
    }

    Connections {
        id: audioConnections
        target: serviceSink && serviceSink.audio ? serviceSink.audio : null
        ignoreUnknownSignals: true
        enabled: !!(serviceSink && serviceSink.audio)

        function onVolumeChanged() {
            volume = averageVolumeFromAudio(serviceSink.audio);
        }
        function onMutedChanged() {
            muted = serviceSink.audio.muted;
        }
    }

    Item {
        id: sliderBg
        anchors.fill: parent
        property bool dragging: false
        property real pendingValue: volume
        property real sliderValue: dragging ? pendingValue : volume

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
                sliderBg.pendingValue = Math.min(1, Math.max(0, Math.round(raw * 20) / 20));
            }
            function commitVolume(v) {
                if (!audioReady)
                    return;
                serviceSink.audio.volume = v;
                var chans = serviceSink.audio.volumes || [];
                if (chans.length)
                    serviceSink.audio.volumes = Array(chans.length).fill(v);
            }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8

        Text {
            id: volumeIconItem
            text: volumeIcon
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + Theme.fontSize / 2
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            color: volumeControl.contrastColor
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: function (event) {
                    if (!audioReady)
                        return;
                    if (event.button === Qt.MiddleButton) {
                        muted = !muted;
                        serviceSink.audio.muted = muted;
                    }
                }
            }
        }

        Text {
            id: percentageItem
            text: audioReady ? Math.round(volume * 100) + "%" : "--"
            font.pixelSize: Theme.fontSize
            font.family: Theme.fontFamily
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            color: volumeControl.contrastColor
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
        }
    }
}
