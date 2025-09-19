pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import qs.Services.Core
import qs.Services.Utils

Singleton {
  id: root

  // Dedicated video applications - PipeWire detection works well here
  readonly property var _videoAppHints: ["mpv", "vlc", "celluloid", "io.github.celluloid_player.celluloid", "org.gnome.totem", "smplayer", "mplayer", "haruna", "kodi", "io.github.iwalton3.jellyfin-media-player", "jellyfin", "plex"]

  // Browser apps - need URL-based detection
  readonly property var _browserAppHints: ["firefox", "zen", "chrome", "chromium", "brave", "vivaldi", "edge", "opera"]

  // Audio-only sites/patterns (explicit exclusions)
  readonly property var _audioOnlyPatterns: ["music.youtube.com", "spotify.com", "soundcloud.com", "music.apple.com", "deezer.com", "tidal.com", "bandcamp.com"]

  // Video sites/patterns
  readonly property var _videoPatterns: ["youtube.com/watch", "youtu.be/", "netflix.com", "primevideo.com", "vimeo.com", "twitch.tv", "hulu.com", "disneyplus.com", "crunchyroll.com", "max.com", "hbomax.com"]

  readonly property var _videoFileExts: ["mp4", "mkv", "webm", "avi", "mov", "m4v", "mpeg", "mpg", "wmv", "flv"]

  // PipeWire video detection for dedicated apps
  readonly property bool _pipewireVideoActive: _hasActiveVideoStreams()

  // Main properties
  readonly property MprisPlayer active: _selectActivePlayer()
  readonly property string activeDisplayName: active ? (active.identity || "Unknown player") : "No player"
  readonly property string activeIconName: _iconNameForPlayer(active)
  readonly property list<MprisPlayer> allPlayers: Mpris.players ? Mpris.players.values : []

  // Hybrid video detection
  readonly property bool anyVideoPlaying: allPlayers.some(player => {
    if (!player || player.playbackState !== MprisPlaybackState.Playing)
      return false;

    // Dedicated video apps: trust PipeWire detection
    if (_isVideoApp(player)) {
      return true; // Assume dedicated video apps are always playing video when active
    }

    // Browser apps: use intelligent URL detection
    if (_isBrowserApp(player)) {
      const url = _getMetadataUrl(player);
      return _isVideoUrl(url);
    }

    return false;
  })

  // Rest of properties...
  property bool canGoNext: active?.canGoNext ?? false
  property bool canGoPrevious: active?.canGoPrevious ?? false
  property bool canPause: active?.canPause ?? false
  property bool canPlay: active?.canPlay ?? false
  property bool canSeek: active?.canSeek ?? false
  property real currentPosition: 0
  readonly property bool hasActive: !!active
  readonly property bool hasPlayers: players.length > 0
  readonly property real infiniteTrackLength: 922337203685
  property bool isPlaying: active?.isPlaying ?? false

  property string lastActiveKey: ""
  property MprisPlayer manualActive: null
  readonly property list<MprisPlayer> players: allPlayers.filter(player => player?.canControl)
  property int selectedPlayerIndex: -1

  property string trackAlbum: active?.trackAlbum ?? ""
  property string trackArtUrl: active?.trackArtUrl ?? ""
  property string trackArtist: active?.trackArtist ?? ""
  property real trackLength: active ? ((active.length < infiniteTrackLength) ? active.length : 0) : 0
  property string trackTitle: active?.trackTitle ?? ""

  function _hasActiveVideoStreams() {
    if (!Pipewire.nodes)
      return false;

    return Pipewire.nodes.values.some(node => {
      if (!node?.isStream)
        return false;

      const props = node.properties || {};
      const mediaClass = String(props["media.class"] || "").toLowerCase();
      const mediaRole = String(props["media.role"] || "").toLowerCase();

      return mediaClass.includes("video") || mediaRole === "movie" || mediaRole === "video";
    });
  }

  function _isVideoUrl(url) {
    if (!url)
      return false;
    const lowerUrl = String(url).toLowerCase();

    // First check: explicit audio-only exclusions
    if (_audioOnlyPatterns.some(pattern => lowerUrl.includes(pattern))) {
      return false;
    }

    // Second check: video site patterns
    if (_videoPatterns.some(pattern => lowerUrl.includes(pattern))) {
      return true;
    }

    // Third check: video file extensions
    const extensionMatch = lowerUrl.match(/\.([a-z0-9]{2,5})(?:\?|#|$)/);
    if (extensionMatch[1] && _videoFileExts.includes(extensionMatch[1])) {
      return true;
    }

    return false;
  }

  function _isBrowserApp(player) {
    if (!player)
      return false;
    const desktopEntry = String(player.desktopEntry || "").toLowerCase();
    const identity = String(player.identity || "").toLowerCase();
    return _browserAppHints.some(hint => desktopEntry.includes(hint) || identity.includes(hint));
  }

  function _isVideoApp(player) {
    if (!player)
      return false;
    const desktopEntry = String(player.desktopEntry || "").toLowerCase();
    const identity = String(player.identity || "").toLowerCase();
    return _videoAppHints.some(hint => desktopEntry.includes(hint) || identity.includes(hint));
  }

  function _getMetadataUrl(player) {
    try {
      const metadata = player?.metadata;
      return String(metadata["xesam:url"] || metadata["xesam:URL"] || "");
    } catch (e) {
      return "";
    }
  }

  function _selectActivePlayer() {
    if (manualActive && _isValidPlayer(manualActive))
      return manualActive;
    if (selectedPlayerIndex >= 0 && selectedPlayerIndex < players.length) {
      return players[selectedPlayerIndex];
    }
    return players.find(p => p.playbackState === MprisPlaybackState.Playing) || players.find(p => p.canControl && p.canPlay) || players[0] || null;
  }

  function _iconNameForPlayer(player) {
    if (!player)
      return "audio-x-generic";

    const normalize = name => String(name).toLowerCase().replace(/[^a-z0-9+.-]/g, "-");
    const canonical = name => {
      const lower = String(name).toLowerCase();
      if (lower.includes("google chrome") || lower === "chrome")
        return "google-chrome";
      if (lower.includes("microsoft edge") || lower === "edge")
        return "microsoft-edge";
      if (lower.includes("firefox"))
        return "firefox";
      if (lower.includes("zen"))
        return "zen";
      if (lower.includes("brave"))
        return "brave-browser";
      return name;
    };

    const desktopEntry = canonical(player.desktopEntry || "");
    if (desktopEntry)
      return normalize(desktopEntry) || "audio-x-generic";

    const identity = canonical(player.identity || "");
    return normalize(identity) || "audio-x-generic";
  }

  function _isValidPlayer(player) {
    return !!player && allPlayers.includes(player);
  }

  // All the control functions remain the same...
  function next() {
    if (active && canGoNext)
      active.next();
  }
  function pause() {
    if (active && canPause)
      active.pause();
  }
  function play() {
    if (active && canPlay)
      active.play();
  }
  function playPause() {
    if (!active)
      return;
    if (active.isPlaying && canPause)
      active.pause();
    else if (!active.isPlaying && canPlay)
      active.play();
  }
  function playerKey(player) {
    if (!player)
      return "";
    return player.desktopEntry || player.busName || player.identity || "";
  }
  function previous() {
    if (active && canGoPrevious)
      active.previous();
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
  function stop() {
    if (active)
      active.stop();
  }

  // Event handlers
  onActiveChanged: {
    if (!active || !_isValidPlayer(active)) {
      currentPosition = 0;
      return;
    }
    currentPosition = active.isPlaying ? active.position : 0;
    const key = playerKey(active);
    if (key && key !== lastActiveKey)
      lastActiveKey = key;
  }

  Connections {
    target: Mpris.players
    function onValuesChanged() {
      if (root.selectedPlayerIndex >= root.players.length)
        root.selectedPlayerIndex = -1;
      if (root.manualActive && !root.allPlayers.includes(root.manualActive))
        root.manualActive = null;
    }
  }

  Timer {
    id: positionTimer
    interval: 1000
    repeat: true
    running: root.active && root.allPlayers.includes(root.active) && root.active.isPlaying && root.trackLength > 0 && root.active.playbackState === MprisPlaybackState.Playing

    onTriggered: {
      if (root.active && root.allPlayers.includes(root.active) && root.active.isPlaying && root.active.playbackState === MprisPlaybackState.Playing) {
        root.currentPosition = root.active.position;
      } else {
        running = false;
      }
    }
  }
}
