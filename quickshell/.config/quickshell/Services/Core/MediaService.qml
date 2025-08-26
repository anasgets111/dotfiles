pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Services.Utils

Singleton {
    id: root

    readonly property list<MprisPlayer> allPlayers: Mpris.players ? Mpris.players.values : []
    readonly property list<MprisPlayer> players: allPlayers.filter(player => player && player.canControl)
    readonly property bool hasPlayers: players.length > 0
    readonly property bool hasActive: !!active
    readonly property string activeIconName: iconNameForPlayer(active)
    readonly property string activeAlbumName: trackAlbum
    readonly property string activeAlbumArtUrl: trackArtUrl
    readonly property string activeDisplayName: active ? (active.identity || "Unknown player") : "No player"
    readonly property real infiniteTrackLength: 922337203685
    property MprisPlayer manualActive: null            // If set, takes precedence
    property int selectedPlayerIndex: -1               // If >=0 and valid, selects that player
    property bool isPlaying: active ? active.isPlaying : false
    property string trackTitle: active ? (active.trackTitle || "") : ""
    property string trackArtist: active ? (active.trackArtist || "") : ""
    property string trackAlbum: active ? (active.trackAlbum || "") : ""
    property string trackArtUrl: active ? (active.trackArtUrl || "") : ""
    property real trackLength: active ? ((active.length < infiniteTrackLength) ? active.length : 0) : 0
    property bool canPlay: active ? active.canPlay : false
    property bool canPause: active ? active.canPause : false
    property bool canGoNext: active ? active.canGoNext : false
    property bool canGoPrevious: active ? active.canGoPrevious : false
    property bool canToggle: active ? active.canTogglePlaying : false
    property bool canSeek: active ? active.canSeek : false
    property real currentPosition: 0

    // Order: manual -> selected index -> playing -> Spotify -> controllable playable -> first
    readonly property MprisPlayer active: (
        manualActive
        || (selectedPlayerIndex >= 0 && selectedPlayerIndex < players.length ? players[selectedPlayerIndex] : null)
        || players.find(player => player.isPlaying)
        || allPlayers.find(player => player.identity === "Spotify")
        || players.find(player => player.canControl && player.canPlay)
        || players[0]
        || null
    )

    function iconNameForPlayer(player) {
        if (!player)
            return "audio-x-generic";

        function normalize(name) {
            try {
                return String(name).toLowerCase().replace(/[^a-z0-9+.-]/g, "-");
            } catch (e) {
                return "";
            }
        }
        function canonical(name) {
            const lowerName = String(name).toLowerCase();
            if (lowerName.indexOf("google chrome") !== -1 || lowerName === "chrome")
                return "google-chrome";
            if (lowerName.indexOf("microsoft edge") !== -1 || lowerName === "edge")
                return "microsoft-edge";
            if (lowerName.indexOf("firefox") !== -1)
                return "firefox";
            if (lowerName.indexOf("zen") !== -1)
                return "zen";
            if (lowerName.indexOf("brave") !== -1)
                return "brave-browser";
            if (lowerName.indexOf("youtube music") !== -1 || lowerName.indexOf("youtubemusic") !== -1)
                return "youtube-music";
            return name;
        }

        const desktopEntry = player.desktopEntry || "";
        if (desktopEntry) {
            const canonicalDesktopEntry = canonical(desktopEntry);
            const normalizedDesktopEntry = normalize(canonicalDesktopEntry);
            return normalizedDesktopEntry || "audio-x-generic";
        }

        const identityString = player.identity || "";
        const canonicalIdentity = canonical(identityString);
        const normalizedIdentity = normalize(canonicalIdentity);
        return normalizedIdentity || "audio-x-generic";
    }

    onActiveChanged: {
        // Reset or sync position when active player changes
        currentPosition = active ? (active.isPlaying ? active.position : 0) : 0;
        if (active)
            Logger.log("MediaService", "active ->", active.identity, "playing=", active.isPlaying);
        else
            Logger.log("MediaService", "active -> none; players=", root.players.length);
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() {
            if (root.selectedPlayerIndex >= root.players.length) {
                Logger.warn("MediaService", "resetting selected index (", root.selectedPlayerIndex, ") due to players shrink");
                root.selectedPlayerIndex = -1;
            }
        }
    }

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
}
