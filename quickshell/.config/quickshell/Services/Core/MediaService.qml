pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Unified MediaService: combines manual/auto player selection, metadata/capabilities,
// position tracking, keyboard shortcuts, and IPC control.
Singleton {
    id: root

    // Players
    readonly property list<MprisPlayer> allPlayers: Mpris.players ? Mpris.players.values : []
    readonly property list<MprisPlayer> players: allPlayers.filter(p => p && p.canControl)
    // Back-compat alias used by some consumers
    readonly property list<MprisPlayer> list: players

    // Selection overrides
    property MprisPlayer manualActive: null            // If set, takes precedence
    property int selectedPlayerIndex: -1               // If >=0 and valid, selects that player

    // Active player resolution: manual -> selected index -> playing -> Spotify -> controllable playable -> first
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

    // Metadata and capabilities (mirrors active player where possible)
    property bool isPlaying: active ? active.isPlaying : false
    property string trackTitle: active ? (active.trackTitle || "") : ""
    property string trackArtist: active ? (active.trackArtist || "") : ""
    property string trackAlbum: active ? (active.trackAlbum || "") : ""
    property string trackArtUrl: active ? (active.trackArtUrl || "") : ""
    property real infiniteTrackLength: 922337203685
    property real trackLength: active ? ((active.length < infiniteTrackLength) ? active.length : 0) : 0

    property bool canPlay: active ? active.canPlay : false
    property bool canPause: active ? active.canPause : false
    property bool canGoNext: active ? active.canGoNext : false
    property bool canGoPrevious: active ? active.canGoPrevious : false
    property bool canToggle: active ? active.canTogglePlaying : false
    property bool canSeek: active ? active.canSeek : false

    // Position tracking (updated while playing)
    property real currentPosition: 0

    onActiveChanged: {
        // Reset or sync position when active player changes
        currentPosition = active ? (active.isPlaying ? active.position : 0) : 0;
    }

    // Keep selected index sane as players appear/disappear
    Connections {
        target: Mpris.players
        function onValuesChanged() {
            if (root.selectedPlayerIndex >= root.players.length)
                root.selectedPlayerIndex = -1;
        }
    }

    Timer {
        id: positionTimer
        interval: 1000
        repeat: true
        running: root.active && root.isPlaying && root.trackLength > 0 && root.active.playbackState === MprisPlaybackState.Playing
        onTriggered: {
            if (root.active && root.isPlaying && root.active.playbackState === MprisPlaybackState.Playing)
                root.currentPosition = root.active.position;
            else
                running = false;
        }
    }

    // Controls API (callable from QML/IPC)
    function playPause() {
        if (active) {
            if (active.isPlaying && canPause)
                active.pause();
            else if (!active.isPlaying && canPlay)
                active.play();
        }
    }

    function play() {
        if (active && canPlay)
            active.play();
    }
    function pause() {
        if (active && canPause)
            active.pause();
    }
    function next() {
        if (active && canGoNext)
            active.next();
    }
    function previous() {
        if (active && canGoPrevious)
            active.previous();
    }
    function stop() {
        if (active)
            active.stop();
    }

    function seek(position) {
        if (active && canSeek) {
            active.position = position;
            currentPosition = position;
        }
    }

    function seekByRatio(ratio) {
        if (active && canSeek && trackLength > 0) {
            const seekPosition = ratio * trackLength;
            active.position = seekPosition;
            currentPosition = seekPosition;
        }
    }

    // Keyboard shortcuts can be wired by the shell/WM; IPC methods below provide control hooks.

    // IPC interface for external control
    IpcHandler {
        target: "mpris"

        function getActive(prop) {
            const a = root.active;
            if (!a)
                return "No active player";
            const v = a[prop];
            return (v === undefined) ? "Invalid property" : v;
        }

        function list() {
            return root.players.map(p => p.identity).join("\n");
        }

        function play() {
            if (root.active && root.active.canPlay)
                root.active.play();
        }
        function pause() {
            if (root.active && root.active.canPause)
                root.active.pause();
        }
        function playPause() {
            if (root.active && root.active.canTogglePlaying)
                root.active.togglePlaying();
        }
        function previous() {
            if (root.active && root.active.canGoPrevious)
                root.active.previous();
        }
        function next() {
            if (root.active && root.active.canGoNext)
                root.active.next();
        }
        function stop() {
            if (root.active)
                root.active.stop();
        }
        function seek(position) {
            root.seek(position);
        }
        function seekByRatio(ratio) {
            root.seekByRatio(ratio);
        }
    }
}
