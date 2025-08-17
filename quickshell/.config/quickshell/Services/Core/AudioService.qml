pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // Properties — discover nodes -> lists of sinks/sources (exclude streams)
    readonly property var nodes: Pipewire.nodes.values.reduce((acc, node) => {
        if (!node.isStream) {
            if (node.isSink)
                acc.sinks.push(node);
            else if (node.audio)
                acc.sources.push(node);
        }
        return acc;
    }, {
        sources: [],
        sinks: []
    })

    // Defaults and lists
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property list<PwNode> sinks: nodes.sinks
    readonly property list<PwNode> sources: nodes.sources

    // Reactive exposed state (0..1) with private mirrors
    readonly property alias volume: root._volume
    property real _volume: (root.sink && root.sink.audio ? root.sink.audio.volume : 0)

    readonly property alias muted: root._muted
    property bool _muted: !!(root.sink && root.sink.audio && root.sink.audio.muted)

    // Step amount for increase/decrease helpers (0..1)
    readonly property real stepVolume: 0.05

    // Signals
    signal micMuteChanged

    // Functions — Human-friendly device naming
    function displayName(node) {
        if (!node)
            return "";

        const props = node.properties || {};
        const deviceDesc = props["device.description"];
        if (deviceDesc)
            return deviceDesc;

        const description = node.description ?? "";
        const nickname = node.nickname ?? "";
        const name = node.name ?? "";

        if (description && description !== name)
            return description;
        if (nickname && nickname !== name)
            return nickname;

        const lname = String(name).toLowerCase();
        if (lname.includes("analog-stereo"))
            return "Built-in Speakers";
        if (lname.includes("bluez"))
            return "Bluetooth Audio";
        if (lname.includes("usb"))
            return "USB Audio";
        if (lname.includes("hdmi"))
            return "HDMI Audio";

        return name;
    }

    function subtitle(name) {
        if (!name)
            return "";

        const lname = String(name).toLowerCase();

        if (lname.includes('usb-')) {
            if (lname.includes('steelseries')) {
                return "USB Gaming Headset";
            } else if (lname.includes('generic')) {
                return "USB Audio Device";
            }
            return "USB Audio";
        } else if (lname.includes('pci-')) {
            if (lname.includes('01_00.1') || lname.includes('01:00.1')) {
                return "NVIDIA GPU Audio";
            }
            return "PCI Audio";
        } else if (lname.includes('bluez')) {
            return "Bluetooth Audio";
        } else if (lname.includes('analog')) {
            return "Built-in Audio";
        } else if (lname.includes('hdmi')) {
            return "HDMI Audio";
        }

        return "";
    }

    // Volume control helpers (percentage-based API retained for IPC)
    function setVolume(percentage) {
        const n = Number.parseInt(percentage, 10);
        if (Number.isNaN(n))
            return "Invalid percentage";
        if (root.sink && root.sink.audio) {
            const clamped = Math.max(0, Math.min(100, n));
            setVolumeReal(clamped / 100);
            return "Volume set to " + clamped + "%";
        }
        return "No audio sink available";
    }

    // Real volume setter (0..1)
    function setVolumeReal(newVolume) {
        if (root.sink && root.sink.audio && root.sink.ready) {
            root.sink.audio.muted = false;
            root.sink.audio.volume = Math.max(0, Math.min(1, newVolume));
            // _volume is updated via Connections
        }
    }

    function toggleMute() {
        if (root.sink && root.sink.audio) {
            const next = !root.sink.audio.muted;
            setMuted(next);
            return next ? "Audio muted" : "Audio unmuted";
        }
        return "No audio sink available";
    }

    function setMuted(muted) {
        if (root.sink && root.sink.audio && root.sink.ready) {
            root.sink.audio.muted = !!muted;
        }
    }

    function increaseVolume() {
        setVolumeReal(root.volume + root.stepVolume);
    }
    function decreaseVolume() {
        setVolumeReal(root.volume - root.stepVolume);
    }

    function setMicVolume(percentage) {
        const n = Number.parseInt(percentage, 10);
        if (Number.isNaN(n))
            return "Invalid percentage";
        if (root.source && root.source.audio) {
            const clamped = Math.max(0, Math.min(100, n));
            root.source.audio.volume = clamped / 100;
            root.micMuteChanged();
            return "Microphone volume set to " + clamped + "%";
        }
        return "No audio source available";
    }

    function toggleMicMute() {
        if (root.source && root.source.audio) {
            root.source.audio.muted = !root.source.audio.muted;
            root.micMuteChanged();
            return root.source.audio.muted ? "Microphone muted" : "Microphone unmuted";
        }
        return "No audio source available";
    }

    // Default device switching
    function setAudioSink(newSink) {
        Pipewire.preferredDefaultAudioSink = newSink;
    }
    function setAudioSource(newSource) {
        Pipewire.preferredDefaultAudioSource = newSource;
    }

    // Objects — trackers, IPC, connections
    PwObjectTracker {
        objects: root.sinks.concat(root.sources)
    }

    // IPC Handler for external control
    IpcHandler {
        target: "audio"

        function setvolume(percentage) {
            return root.setVolume(percentage);
        }

        function increment(step) {
            if (root.sink && root.sink.audio) {
                if (root.sink.audio.muted)
                    root.sink.audio.muted = false;

                const currentVolume = Math.round(root.sink.audio.volume * 100);
                const parsed = Number.parseInt(step ?? "5", 10);
                const delta = Number.isNaN(parsed) ? 5 : parsed;
                const newVolume = Math.max(0, Math.min(100, currentVolume + delta));
                root.sink.audio.volume = newVolume / 100;
                return "Volume increased to " + newVolume + "%";
            }
            return "No audio sink available";
        }

        function decrement(step) {
            if (root.sink && root.sink.audio) {
                if (root.sink.audio.muted)
                    root.sink.audio.muted = false;

                const currentVolume = Math.round(root.sink.audio.volume * 100);
                const parsed = Number.parseInt(step ?? "5", 10);
                const delta = Number.isNaN(parsed) ? 5 : parsed;
                const newVolume = Math.max(0, Math.min(100, currentVolume - delta));
                root.sink.audio.volume = newVolume / 100;
                return "Volume decreased to " + newVolume + "%";
            }
            return "No audio sink available";
        }

        function mute() {
            return root.toggleMute();
        }

        function setmic(percentage) {
            return root.setMicVolume(percentage);
        }

        function micmute() {
            return root.toggleMicMute();
        }

        function status() {
            let result = "Audio Status:\n";
            if (root.sink && root.sink.audio) {
                const volume = Math.round(root.sink.audio.volume * 100);
                result += "Output: " + volume + "%" + (root.sink.audio.muted ? " (muted)" : "") + "\n";
            } else {
                result += "Output: No sink available\n";
            }

            if (root.source && root.source.audio) {
                const micVolume = Math.round(root.source.audio.volume * 100);
                result += "Input: " + micVolume + "%" + (root.source.audio.muted ? " (muted)" : "");
            } else {
                result += "Input: No source available";
            }

            return result;
        }
    }

    // React to underlying audio changes (external mixers, device switches)
    Connections {
        target: root.sink && root.sink.audio ? root.sink.audio : null
        function onVolumeChanged() {
            var vol = (root.sink && root.sink.audio ? root.sink.audio.volume : 0);
            if (isNaN(vol))
                vol = 0;
            root._volume = vol;
        }
        function onMutedChanged() {
            root._muted = !!(root.sink && root.sink.audio && root.sink.audio.muted);
        }
    }
    Connections {
        target: root.source && root.source.audio ? root.source.audio : null
        function onVolumeChanged() {
            root.micMuteChanged();
        }
        function onMutedChanged() {
            root.micMuteChanged();
        }
    }

    // Also update/emit when default devices flip
    onSinkChanged: {
        root._volume = (root.sink && root.sink.audio ? root.sink.audio.volume : 0);
        root._muted = !!(root.sink && root.sink.audio && root.sink.audio.muted);
    }
    onSourceChanged: root.micMuteChanged()
}
