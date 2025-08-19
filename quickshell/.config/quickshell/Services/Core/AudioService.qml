pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Services.SystemInfo

Singleton {
    id: root

    // Properties — lists of sinks/sources (exclude streams)
    readonly property var logger: LoggerService
    // Defaults and lists
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property list<PwNode> sinks: Pipewire.nodes.values.filter(n => !n.isStream && n.isSink)
    readonly property list<PwNode> sources: Pipewire.nodes.values.filter(n => !n.isStream && !n.isSink && n.audio)

    // Reactive exposed state (0..1) with private mirrors
    readonly property alias volume: root._volume
    property real _volume: (root.sink && root.sink.audio ? root.sink.audio.volume : 0)

    readonly property alias muted: root._muted
    property bool _muted: !!(root.sink && root.sink.audio && root.sink.audio.muted)

    // Step amount for increase/decrease helpers (0..1)
    readonly property real stepVolume: 0.05

    // Signals
    signal micMuteChanged

    // Lifecycle
    Component.onCompleted: {
        logger.log("AudioService", "ready; default sink=", root.displayName(root.sink), "muted=", !!(root.sink && root.sink.audio && root.sink.audio.muted), "volume=", Math.round((root.sink && root.sink.audio ? root.sink.audio.volume : 0) * 100) + "%", "default source=", root.displayName(root.source));
    }

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
            logger.log("AudioService", "setVolume request:", clamped + "%");
            setVolumeReal(clamped / 100);
            return "Volume set to " + clamped + "%";
        }
        return "No audio sink available";
    }

    // Real volume setter (0..1)
    function setVolumeReal(newVolume) {
        if (root.sink && root.sink.audio && root.sink.ready) {
            logger.log("AudioService", "setVolumeReal:", Math.round(newVolume * 100) + "%");
            root.sink.audio.muted = false;
            root.sink.audio.volume = Math.max(0, Math.min(1, newVolume));
            // _volume is updated via Connections
        }
    }

    function toggleMute() {
        if (root.sink && root.sink.audio) {
            const next = !root.sink.audio.muted;
            logger.log("AudioService", "toggleMute ->", next ? "muted" : "unmuted");
            setMuted(next);
            return next ? "Audio muted" : "Audio unmuted";
        }
        return "No audio sink available";
    }

    function setMuted(muted) {
        if (root.sink && root.sink.audio && root.sink.ready) {
            logger.log("AudioService", "setMuted:", !!muted);
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
            logger.log("AudioService", "setMicVolume:", clamped + "%");
            root.source.audio.volume = clamped / 100;
            root.micMuteChanged();
            return "Microphone volume set to " + clamped + "%";
        }
        return "No audio source available";
    }

    function toggleMicMute() {
        if (root.source && root.source.audio) {
            root.source.audio.muted = !root.source.audio.muted;
            logger.log("AudioService", "toggleMicMute ->", root.source.audio.muted ? "muted" : "unmuted");
            root.micMuteChanged();
            return root.source.audio.muted ? "Microphone muted" : "Microphone unmuted";
        }
        return "No audio source available";
    }

    // Default device switching
    function setAudioSink(newSink) {
        logger.log("AudioService", "setAudioSink:", root.displayName(newSink));
        Pipewire.preferredDefaultAudioSink = newSink;
    }
    function setAudioSource(newSource) {
        logger.log("AudioService", "setAudioSource:", root.displayName(newSource));
        Pipewire.preferredDefaultAudioSource = newSource;
    }

    // Objects — trackers, IPC, connections
    PwObjectTracker {
        objects: root.sinks.concat(root.sources)
    }

    // IPC Handler for external control
    IpcHandler {
        target: "audio"

        function setvolume(percentage: string): string {
            root.logger.log("AudioService:IPC", "setvolume", percentage);
            return root.setVolume(percentage);
        }

        function increment(step: string): string {
            if (root.sink && root.sink.audio) {
                if (root.sink.audio.muted)
                    root.sink.audio.muted = false;

                const currentVolume = Math.round(root.sink.audio.volume * 100);
                const parsed = Number.parseInt(step ?? "5", 10);
                const delta = Number.isNaN(parsed) ? 5 : parsed;
                const newVolume = Math.max(0, Math.min(100, currentVolume + delta));
                root.sink.audio.volume = newVolume / 100;
                root.logger.log("AudioService:IPC", "increment", delta, "->", newVolume + "%");
                return "Volume increased to " + newVolume + "%";
            }
            return "No audio sink available";
        }

        function decrement(step: string): string {
            if (root.sink && root.sink.audio) {
                if (root.sink.audio.muted)
                    root.sink.audio.muted = false;

                const currentVolume = Math.round(root.sink.audio.volume * 100);
                const parsed = Number.parseInt(step ?? "5", 10);
                const delta = Number.isNaN(parsed) ? 5 : parsed;
                const newVolume = Math.max(0, Math.min(100, currentVolume - delta));
                root.sink.audio.volume = newVolume / 100;
                root.logger.log("AudioService:IPC", "decrement", delta, "->", newVolume + "%");
                return "Volume decreased to " + newVolume + "%";
            }
            return "No audio sink available";
        }

        function mute(): string {
            root.logger.log("AudioService:IPC", "mute");
            return root.toggleMute();
        }

        function setmic(percentage: string): string {
            root.logger.log("AudioService:IPC", "setmic", percentage);
            return root.setMicVolume(percentage);
        }

        function micmute(): string {
            root.logger.log("AudioService:IPC", "micmute");
            return root.toggleMicMute();
        }

        function status(): string {
            root.logger.log("AudioService:IPC", "status");
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
            root.logger.log("AudioService", "sink volume changed ->", Math.round(vol * 100) + "%");
        }
        function onMutedChanged() {
            root._muted = !!(root.sink && root.sink.audio && root.sink.audio.muted);
            root.logger.log("AudioService", "sink muted changed ->", root._muted);
        }
    }
    Connections {
        target: root.source && root.source.audio ? root.source.audio : null
        function onVolumeChanged() {
            root.logger.log("AudioService", "mic volume changed ->", Math.round(root.source.audio.volume * 100) + "%");
            root.micMuteChanged();
        }
        function onMutedChanged() {
            root.logger.log("AudioService", "mic muted changed ->", !!(root.source && root.source.audio && root.source.audio.muted));
            root.micMuteChanged();
        }
    }

    // Also update/emit when default devices flip
    onSinkChanged: {
        root._volume = (root.sink && root.sink.audio ? root.sink.audio.volume : 0);
        root._muted = !!(root.sink && root.sink.audio && root.sink.audio.muted);
        logger.log("AudioService", "default sink changed ->", root.displayName(root.sink), "muted=", root._muted, "volume=", Math.round(root._volume * 100) + "%");
    }
    onSourceChanged: {
        logger.log("AudioService", "default source changed ->", root.displayName(root.source));
        root.micMuteChanged();
    }
}
