import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

pragma ComponentBehavior: Bound

Rectangle {
    id: volumeControl
    // prevent any child-overflow when collapsed
    clip: true



    property int expandedWidth:  220

    // exact collapsed width = icon + percent + 2×spacing
    property real collapsedWidth:
        volumeIconItem.implicitWidth +
        percentageItem.implicitWidth +
        contentRow.spacing * 2

    // slider expands from 0 → this
    property real sliderMaxWidth:
        expandedWidth - collapsedWidth

    width: collapsedWidth
    height: contentRow.implicitHeight
    radius: Theme.itemRadius
    color: Theme.inactiveColor

    states: [
        State {
            name: "hovered"
            when: rootArea.containsMouse
            PropertyChanges { target: volumeControl; width: expandedWidth; color: Theme.activeColor }
        }
    ]

    MouseArea {
        id: rootArea
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: expandedWidth
        height: parent.height
        hoverEnabled: true
        // allow clicks to fall through to the slider’s MouseArea
        acceptedButtons: Qt.NoButton

        onWheel: function(event) {
            if (!audioReady) return;
            var step = 0.05;
            var delta = event.angleDelta.y > 0 ? step : -step;
            var newVolume = Math.max(0, Math.min(1, volume + delta));
            if (serviceSink && serviceSink.audio) {
                serviceSink.audio.volume = newVolume;
                var chans = serviceSink.audio.volumes || [];
                if (chans.length) {
                    serviceSink.audio.volumes = Array(chans.length).fill(newVolume);
                }
            }
            event.accepted = true;
        }
    }

    property PwNode serviceSink: Pipewire.defaultAudioSink



    property real volume:    0.0
    property bool muted:     false

    property string volumeIcon: audioReady
        ? (muted ? "󰝟"
            : volume < 0.01 ? "󰖁"
            : volume < 0.33 ? "󰕿"
            : volume < 0.66 ? "󰖀" : "󰕾" )
        : "--"

    property bool audioReady:
        Pipewire.ready === true &&
        serviceSink !== null &&
        serviceSink.ready === true &&
        serviceSink.audio !== null

    Component.onCompleted:    bindToSink()
    Connections { target: Pipewire; ignoreUnknownSignals: true
        function onReadyChanged()       { bindToSink() }
        function onDefaultAudioSinkChanged() { bindToSink() }
    }

    function averageVolumeFromAudio(audio) {
        if (!audio) return 0.0;
        var v = audio.volume;
        if (typeof v === "number" && !isNaN(v)) {
            return v;
        } else if (Array.isArray(audio.volumes)) {
            return audio.volumes.length
                ? audio.volumes.reduce((s, v) => s + v, 0) / audio.volumes.length
                : 0.0;
        }
        return 0.0;
    }

    function bindToSink() {
        volume = 0.0
        muted  = false

        if (Pipewire.ready) {
            serviceSink = Pipewire.defaultAudioSink;
        }
        if (serviceSink && serviceSink.audio) {
            volume = averageVolumeFromAudio(serviceSink.audio);
        }
    }

    PwObjectTracker {
        id: pwTracker
        objects: (serviceSink && serviceSink.audio)
                 ? [ serviceSink, serviceSink.audio ]
                 : (serviceSink ? [serviceSink] : [])
    }

    Connections {
        id: audioConnections
        target: serviceSink && serviceSink.audio ? serviceSink.audio : null
        ignoreUnknownSignals: true
        enabled: !!(serviceSink && serviceSink.audio)

        function onVolumeChanged() {
            volume = averageVolumeFromAudio(serviceSink.audio);
        }

        function onMutedChanged(m) {
            muted = m
        }
    }

    // Slider visuals as a separate element
    Component {
        id: volumeSliderComponent
        Item {
            id: sliderContainer
            height: contentRow.implicitHeight
            width: parent ? parent.width : 0
            property bool dragging: false
            property real pendingValue: volume
            property real sliderValue: dragging ? pendingValue : volume

            // track
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                height: 4
                y: (parent.height - height) / 2
                radius: 2
                color: Theme.inactiveColor
            }
            // fill
            Rectangle {
                anchors.left: parent.left
                y: (parent.height - 4) / 2
                width: parent.width * (sliderContainer.dragging
                    ? sliderContainer.pendingValue
                    : volume)
                height: 4
                radius: 2
                color: Theme.textActiveColor
            }
            // handle
            Rectangle {
                width: 12; height: 12
                x: (sliderContainer.dragging
                    ? sliderContainer.pendingValue
                    : volume) *
                    (parent.width - width)
                y: (parent.height - height) / 2
                radius: 6
                color: Theme.textActiveColor
                border.color: Theme.bgColor
                border.width: 1
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.NoButton
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: false
                cursorShape: Qt.PointingHandCursor
                propagateComposedEvents: true

                onPressed: function(evt) {
                    sliderContainer.dragging = true
                    var raw  = evt.x / width
                    var step = Math.round(raw * 20) / 20
                    sliderContainer.pendingValue = Math.min(1, Math.max(0, step))
                }
                onPositionChanged: function(evt) {
                    if (!sliderContainer.dragging) return
                    var raw  = evt.x / width
                    var step = Math.round(raw * 20) / 20
                    sliderContainer.pendingValue = Math.min(1, Math.max(0, step))
                }
                onReleased: function() {
                    sliderContainer.dragging = false
                    var v = sliderContainer.pendingValue
                    if (serviceSink && serviceSink.audio) {
                        serviceSink.audio.volume = v
                        var chans = serviceSink.audio.volumes || []
                        if (chans.length) {
                            serviceSink.audio.volumes = Array(chans.length).fill(v)
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8
        Layout.alignment: Qt.AlignVCenter
        clip: true

        // Spacer to give breathing room from the left edge
        Item {
            width: 10
            Layout.preferredWidth: width
        }

        // Slider element, visibility controlled independently
        Item {
            id: sliderWrapper
            height: contentRow.implicitHeight
            Layout.preferredWidth: rootArea.containsMouse ? sliderMaxWidth : 0
            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: Theme.animationDuration
                    easing.type: Easing.InOutQuad
                }
            }
            visible: rootArea.containsMouse || Layout.preferredWidth > 0
            // Loader for the slider visuals
            Loader {
                anchors.fill: parent
                sourceComponent: volumeSliderComponent
            }
        }

        // ICON (static, does not animate)
        Text {
            id: volumeIconItem
            text: volumeIcon
            color: rootArea.containsMouse
                ? Theme.textActiveColor
                : Theme.textInactiveColor
            font.pixelSize: Theme.fontSize + 10
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            // Ensure no margin/padding changes on hover
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: function(mouse) {
                    if (!audioReady) return;
                    if (mouse.button === Qt.MiddleButton && serviceSink && serviceSink.audio) {
                        muted = !muted;
                        serviceSink.audio.muted = muted;
                    }
                }
            }
        }

        // PERCENTAGE (static on hover)
        Text {
            id: percentageItem
            text: audioReady
                ? Math.round(volume * 100) + "%"
                : "--"
            color: rootArea.containsMouse
                ? Theme.textActiveColor
                : Theme.textInactiveColor
            font.pixelSize: Theme.fontSize + 4
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            // Ensure no margin/padding changes on hover
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
        }

        // Spacer to give breathing room to the right edge
        Item {
            width: 10
            Layout.preferredWidth: width
        }
    }

    Behavior on width {
        NumberAnimation { duration: Theme.animationDuration
                          easing.type: Easing.InOutQuad }
    }
    Behavior on color {
        ColorAnimation { duration: Theme.animationDuration
                         easing.type: Easing.InOutQuad }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        visible: !audioReady
        z: 100
        enabled: false
        Text {
            anchors.centerIn: parent
            text: "Audio device not ready"
            color: "red"
            font.pixelSize: Theme.fontSize + 2
        }
    }
}
