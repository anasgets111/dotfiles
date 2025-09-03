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

  // Browsers: only considered "video" when PipeWire has a video-like stream role
  readonly property var _browserAppHints: ["firefox", "zen", "chrome", "chromium", "brave", "vivaldi", "edge", "opera"]
  readonly property bool _pipewireVideoRoleActive: Pipewire.nodes && Pipewire.nodes.values.some(n => n && n.isStream && _nodeHasVideoRole(n))
  // Known video-focused apps (desktopEntry or identity substring, lowercase)
  readonly property var _videoAppHints: [
    // Local video players
    "mpv", "vlc", "celluloid", "io.github.celluloid_player.celluloid", "org.gnome.totem", "smplayer", "mplayer", "haruna", "kodi", "io.github.iwalton3.jellyfin-media-player", "jellyfin", "plex"]
  // Try to detect video via MPRIS metadata URL for browsers as a fallback
  readonly property var _videoDomains: ["youtube.com", "youtu.be", "netflix.com", "primevideo.com", "amazon.com", "vimeo.com", "twitch.tv", "hulu.com", "disneyplus.com", "hotstar.com", "crunchyroll.com", "dailymotion.com", "max.com", "hbomax.com", "tv.apple.com", "peertube", "bilibili.com",
    // Additional regional/other services
    "osnplus.com", "watch.osn.com", "osn.com", "shahid.mbc.net", "shahid.net", "paramountplus.com", "peacocktv.com", "mubi.com"]
  readonly property var _videoFileExts: ["mp4", "mkv", "webm", "avi", "mov", "m4v", "mpeg", "mpg", "wmv", "flv"]

  // Centralized inhibitor via IdleService
  property var _videoToken: null

  // Order: manual -> selected index -> playing -> controllable playable -> first
  readonly property MprisPlayer active: ((manualActive && isValidPlayer(manualActive)) ? manualActive : ((selectedPlayerIndex >= 0 && selectedPlayerIndex < players.length ? players[selectedPlayerIndex] : null) || players.find(player => player && player.playbackState === MprisPlaybackState.Playing) || players.find(player => player.canControl && player.canPlay) || players[0] || null))
  readonly property string activeDisplayName: active ? (active.identity || "Unknown player") : "No player"
  readonly property string activeIconName: iconNameForPlayer(active)
  readonly property list<MprisPlayer> allPlayers: Mpris.players ? Mpris.players.values : []
  readonly property bool anyVideoPlaying: enableVideoIdleInhibit && (allPlayers.some(p => p && p.playbackState === MprisPlaybackState.Playing && _isVideoApp(p)) || allPlayers.some(p => p && p.playbackState === MprisPlaybackState.Playing && _isBrowserApp(p) && (_pipewireVideoRoleActive || _urlLooksVideo(_metadataUrl(p)))))
  property bool canGoNext: active ? active.canGoNext : false
  property bool canGoPrevious: active ? active.canGoPrevious : false
  property bool canPause: active ? active.canPause : false
  property bool canPlay: active ? active.canPlay : false
  property bool canSeek: active ? active.canSeek : false
  property real currentPosition: 0

  // Auto idle-inhibit only for video players
  // This runs a dedicated inhibitor separate from manual toggles/buttons
  // so it won’t interfere with user-controlled inhibition.
  property bool enableVideoIdleInhibit: true
  readonly property bool hasActive: !!active
  readonly property bool hasPlayers: players.length > 0
  readonly property real infiniteTrackLength: 922337203685
  property bool isPlaying: active ? active.isPlaying : false

  // Track last active player (currently informational only)
  property string lastActiveKey: ""
  property MprisPlayer manualActive: null            // If set, takes precedence
  readonly property list<MprisPlayer> players: allPlayers.filter(player => player && player.canControl)
  property int selectedPlayerIndex: -1               // If >=0 and valid, selects that player
  property string trackAlbum: active ? (active.trackAlbum || "") : ""
  property string trackArtUrl: active ? (active.trackArtUrl || "") : ""
  property string trackArtist: active ? (active.trackArtist || "") : ""
  property real trackLength: active ? ((active.length < infiniteTrackLength) ? active.length : 0) : 0
  property string trackTitle: active ? (active.trackTitle || "") : ""
  property string videoInhibitReason: "Video playback"

  function _isBrowserApp(player) {
    if (!player)
      return false;
    const de = String(player.desktopEntry || "").toLowerCase();
    const id = String(player.identity || "").toLowerCase();
    for (let i = 0; i < _browserAppHints.length; i++) {
      const hint = _browserAppHints[i];
      if (!hint)
        continue;
      if ((de && de.indexOf(hint) !== -1) || (id && id.indexOf(hint) !== -1))
        return true;
    }
    return false;
  }
  function _isVideoApp(player) {
    if (!player)
      return false;
    const de = String(player.desktopEntry || "").toLowerCase();
    const id = String(player.identity || "").toLowerCase();
    for (let i = 0; i < _videoAppHints.length; i++) {
      const hint = _videoAppHints[i];
      if (!hint)
        continue;
      if ((de && de.indexOf(hint) !== -1) || (id && id.indexOf(hint) !== -1))
        return true;
    }
    return false;
  }
  function _metadataUrl(player) {
    try {
      const md = player && player.metadata ? player.metadata : null;
      if (!md)
        return "";
      const url = md["xesam:url"] || md["xesam:URL"] || "";
      return String(url || "");
    } catch (e) {
      return "";
    }
  }
  function _nodeHasVideoRole(node) {
    if (!node)
      return false;
    const props = node.properties || {};
    const role = String(props["media.role"] || props["media.category"] || "").toLowerCase();
    // Common roles seen: "video", "movie", sometimes "multimedia"; include variants
    if (role === "video" || role === "movie" || role === "multimedia" || role === "visual" || role === "film")
      return true;
    // Fallback: some apps set media.role to "music" even for videos — avoid matching that to keep audio-only excluded.
    // Optionally consider media.class hints if present
    const mediaClass = String(props["media.class"] || props["node.nick"] || "").toLowerCase();
    // e.g., "Stream/Input/Video" or names containing "video"
    return mediaClass.indexOf("video") !== -1;
  }
  function _urlLooksVideo(url) {
    if (!url)
      return false;
    var lurl = String(url).toLowerCase();
    // Domain match
    for (let i = 0; i < _videoDomains.length; i++) {
      const d = _videoDomains[i];
      if (d && lurl.indexOf(d) !== -1)
        return true;
    }
    // File extension match for local/network files
    const m = lurl.match(/\.([a-z0-9]{2,5})(?:\?|#|$)/);
    if (m && m[1])
      return _videoFileExts.indexOf(m[1]) !== -1;
    return false;
  }
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
  function isValidPlayer(player) {
    return !!player && root.allPlayers.indexOf(player) !== -1;
  }
  function next() {
    if (!active || !isValidPlayer(active)) {
      Logger.warn("MediaService", "next requested but no active player");
      return;
    }
    if (canGoNext) {
      active.next();
    } else {
      Logger.warn("MediaService", "next unsupported for", active.identity);
    }
  }
  function pause() {
    if (!active || !isValidPlayer(active)) {
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
  function play() {
    if (!active || !isValidPlayer(active)) {
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
  function playPause() {
    if (!active || !isValidPlayer(active)) {
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
  function playerKey(player) {
    if (!player)
      return "";
    // Prefer stable identifiers: desktopEntry then bus name or identity
    const de = player.desktopEntry || "";
    const bus = player.busName || ""; // may not exist in some impls
    const id = player.identity || "";
    return de || bus || id;
  }
  function previous() {
    if (!active || !isValidPlayer(active)) {
      Logger.warn("MediaService", "previous requested but no active player");
      return;
    }
    if (canGoPrevious) {
      active.previous();
    } else {
      Logger.warn("MediaService", "previous unsupported for", active.identity);
    }
  }
  function seek(position) {
    if (!active || !isValidPlayer(active)) {
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
    if (!active || !isValidPlayer(active)) {
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
  function stop() {
    if (!active || !isValidPlayer(active)) {
      Logger.warn("MediaService", "stop requested but no active player");
      return;
    }
    active.stop();
  }

  onActiveChanged: {
    // Reset or sync position when active player changes, avoid touching stale players
    if (!active || !isValidPlayer(active)) {
      currentPosition = 0;
      Logger.log("MediaService", "active -> none; players=", root.players.length);
      return;
    }
    currentPosition = active.isPlaying ? active.position : 0;
    Logger.log("MediaService", "active ->", active.identity, "playing=", active.isPlaying);
    // Keep informational only; avoid feeding back into selection
    const k = playerKey(active);
    if (k && k !== lastActiveKey)
      lastActiveKey = k;
  }
  onAnyVideoPlayingChanged: {
    if (anyVideoPlaying) {
      if (!_videoToken) {
        _videoToken = IdleService.acquire(videoInhibitReason);
        Logger.log("MediaService", "Video detected -> enabling idle inhibitor (browserRole=", _pipewireVideoRoleActive, ")");
      }
    } else if (_videoToken) {
      IdleService.release(_videoToken);
      _videoToken = null;
      Logger.log("MediaService", "No video -> disabling idle inhibitor");
    }
  }

  Connections {
    function onValuesChanged() {
      if (root.selectedPlayerIndex >= root.players.length) {
        Logger.warn("MediaService", "resetting selected index (", root.selectedPlayerIndex, ") due to players shrink");
        root.selectedPlayerIndex = -1;
      }
      if (root.manualActive && root.allPlayers.indexOf(root.manualActive) === -1) {
        Logger.warn("MediaService", "clearing manualActive; player vanished");
        root.manualActive = null;
      }
    }

    target: Mpris.players
  }
  Timer {
    id: positionTimer

    interval: 1000
    repeat: true
    running: root.active && root.allPlayers.indexOf(root.active) !== -1 && root.isPlaying && root.trackLength > 0 && root.active.playbackState === MprisPlaybackState.Playing

    // onRunningChanged: no logging
    onTriggered: {
      if (root.active && root.allPlayers.indexOf(root.active) !== -1 && root.isPlaying && root.active.playbackState === MprisPlaybackState.Playing)
        root.currentPosition = root.active.position;
      else
        running = false;
    }
  }
}
