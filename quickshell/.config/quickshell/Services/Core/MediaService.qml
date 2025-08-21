pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Services.Utils

// Unified MediaService: combines manual/auto player selection, metadata/capabilities,
// position tracking, keyboard shortcuts, and IPC control.
Singleton {
    id: root

    // === Players ===
    readonly property list<MprisPlayer> allPlayers: Mpris.players ? Mpris.players.values : []
    readonly property list<MprisPlayer> players: allPlayers.filter(p => p && p.canControl)
    // Back-compat alias used by some consumers
    readonly property list<MprisPlayer> list: players

    // === Selection overrides ===
    property MprisPlayer manualActive: null            // If set, takes precedence
    property int selectedPlayerIndex: -1               // If >=0 and valid, selects that player

    // === Active player resolution ===
    // Order: manual -> selected index -> playing -> Spotify -> controllable playable -> first
    readonly property MprisPlayer active: {
        var chosen = null;
        if (manualActive) {
            chosen = manualActive;
        } else if (selectedPlayerIndex >= 0 && selectedPlayerIndex < players.length) {
            chosen = players[selectedPlayerIndex];
        } else {
            chosen = players.find(p => p.isPlaying) || allPlayers.find(p => p.identity === "Spotify") || players.find(p => p.canControl && p.canPlay) || players[0] || null;
        }
        chosen;
    }

    // === Metadata (mirror active player) ===
    readonly property bool hasPlayers: players.length > 0
    readonly property bool hasActive: active !== null
    property bool isPlaying: active ? active.isPlaying : false
    property string trackTitle: active ? (active.trackTitle || "") : ""
    property string trackArtist: active ? (active.trackArtist || "") : ""
    property string trackAlbum: active ? (active.trackAlbum || "") : ""
    property string trackArtUrl: active ? (active.trackArtUrl || "") : ""
    property real infiniteTrackLength: 922337203685
    property real trackLength: active ? ((active.length < infiniteTrackLength) ? active.length : 0) : 0

    // === Playback capabilities ===
    property bool canPlay: active ? active.canPlay : false
    property bool canPause: active ? active.canPause : false
    property bool canGoNext: active ? active.canGoNext : false
    property bool canGoPrevious: active ? active.canGoPrevious : false
    property bool canToggle: active ? active.canTogglePlaying : false
    property bool canSeek: active ? active.canSeek : false

    // === Convenience (UI helpers) ===
    // Map player identity/desktop entry to a themed icon name with minimal rules.
    function iconNameForPlayer(a) {
        if (!a)
            return "audio-x-generic";

        function normalize(name) {
            try {
                return String(name).toLowerCase().replace(/[^a-z0-9+.-]/g, "-");
            } catch (e) {
                return "";
            }
        }
        function canonical(name) {
            var l = String(name).toLowerCase();
            if (l.indexOf("google chrome") !== -1 || l === "chrome")
                return "google-chrome";
            if (l.indexOf("microsoft edge") !== -1 || l === "edge")
                return "microsoft-edge";
            if (l.indexOf("firefox") !== -1)
                return "firefox";
            if (l.indexOf("zen") !== -1)
                return "zen";
            if (l.indexOf("brave") !== -1)
                return "brave-browser";
            if (l.indexOf("youtube music") !== -1 || l.indexOf("youtubemusic") !== -1)
                return "youtube-music";
            return name;
        }

        // Prefer desktop entry when available; most icon themes ship by that name
        var de = a.desktopEntry || "";
        if (de) {
            var cde = canonical(de);
            var nde = normalize(cde);
            return nde || "audio-x-generic";
        }

        // Fallback: identity-based guess, canonicalized and normalized
        var id = a.identity || "";
        var cid = canonical(id);
        var nid = normalize(cid);
        return nid || "audio-x-generic";
    }

    // Best-effort themed icon name for the active player
    readonly property string activeIconName: iconNameForPlayer(active)
    readonly property string activeAlbumName: trackAlbum
    readonly property string activeAlbumArtUrl: trackArtUrl
    readonly property string activeDisplayName: active ? (active.identity || "Unknown player") : "No player"

    // === Position tracking (updated while playing) ===
    property real currentPosition: 0

    // (no-op) icon name changes are reflected where bound; no extra logging

    onActiveChanged: {
        // Reset or sync position when active player changes
        currentPosition = active ? (active.isPlaying ? active.position : 0) : 0;
        if (active)
            Logger.log("MediaService", "active ->", active.identity, "playing=", active.isPlaying);
        else
            Logger.log("MediaService", "active -> none; players=", root.players.length);
    }

    // Track selection overrides: no extra logs

    // === Player list changes ===
    // Keep selected index sane as players appear/disappear
    Connections {
        target: Mpris.players
        function onValuesChanged() {
            if (root.selectedPlayerIndex >= root.players.length) {
                Logger.warn("MediaService", "resetting selected index (", root.selectedPlayerIndex, ") due to players shrink");
                root.selectedPlayerIndex = -1;
            }
        }
    }

    // === Position timer ===
    Timer {
        id: positionTimer
        interval: 1000
        repeat: true
        running: root.active && root.isPlaying && root.trackLength > 0 && root.active.playbackState === MprisPlaybackState.Playing
        // onRunningChanged: no logging
        onTriggered: {
            if (root.active && root.isPlaying && root.active.playbackState === MprisPlaybackState.Playing)
                root.currentPosition = root.active.position;
            else
                running = false;
        }
    }

    // === Controls API (callable from QML/IPC) ===
    function playPause() {
        if (!active) {
            Logger.warn("MediaService", "playPause requested but no active player");
            return;
        }
        if (active.isPlaying && canPause) {
            active.pause();
        } else if (!active.isPlaying && canPlay) {
            active.play();
        } else {
            Logger.warn("MediaService", "playPause requested but unsupported: playing=", active.isPlaying, "canPlay=", canPlay, "canPause=", canPause);
        }
    }

    function play() {
        if (!active) {
            Logger.warn("MediaService", "play requested but no active player");
            return;
        }
        if (canPlay) {
            active.play();
            Logger.log("MediaService", "play()");
        } else {
            Logger.warn("MediaService", "play unsupported for", active.identity);
        }
    }
    function pause() {
        if (!active) {
            Logger.warn("MediaService", "pause requested but no active player");
            return;
        }
        if (canPause) {
            active.pause();
            Logger.log("MediaService", "pause()");
        } else {
            Logger.warn("MediaService", "pause unsupported for", active.identity);
        }
    }
    function next() {
        if (!active) {
            Logger.warn("MediaService", "next requested but no active player");
            return;
        }
        if (canGoNext) {
            active.next();
        } else {
            Logger.warn("MediaService", "next unsupported for", active.identity);
        }
    }
    function previous() {
        if (!active) {
            Logger.warn("MediaService", "previous requested but no active player");
            return;
        }
        if (canGoPrevious) {
            active.previous();
        } else {
            Logger.warn("MediaService", "previous unsupported for", active.identity);
        }
    }
    function stop() {
        if (!active) {
            Logger.warn("MediaService", "stop requested but no active player");
            return;
        }
        active.stop();
    }

    function seek(position) {
        if (!active) {
            Logger.warn("MediaService", "seek requested but no active player");
            return;
        }
        if (canSeek) {
            active.position = position;
            currentPosition = position;
            // position updated
        } else {
            Logger.warn("MediaService", "seek unsupported for", active.identity);
        }
    }

    function seekByRatio(ratio) {
        if (!active) {
            Logger.warn("MediaService", "seekByRatio requested but no active player");
            return;
        }
        if (canSeek && trackLength > 0) {
            const seekPosition = ratio * trackLength;
            active.position = seekPosition;
            currentPosition = seekPosition;
            // position updated by ratio
        } else {
            Logger.warn("MediaService", "seekByRatio unsupported: canSeek=", canSeek, "length=", trackLength);
        }
    }

    // Keyboard shortcuts can be wired by the shell/WM; IPC methods below provide control hooks.

}
