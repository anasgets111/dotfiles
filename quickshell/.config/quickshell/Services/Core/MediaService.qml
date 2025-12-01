pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

Singleton {
  id: root

  readonly property bool _activeIsVideo: active && (_isVideoApp(active) || (_isBrowserApp(active) && _isVideoUrl(_getUrl(active))))
  readonly property var _audioOnlyPatterns: ["music.youtube.com", "spotify.com", "soundcloud.com", "music.apple.com", "deezer.com", "tidal.com", "bandcamp.com"]
  readonly property var _browserHints: ["firefox", "zen", "chrome", "chromium", "brave", "vivaldi", "edge", "opera"]
  readonly property bool _hasPlayingVideo: players.some(p => p?.playbackState === MprisPlaybackState.Playing && (_isVideoApp(p) || (_isBrowserApp(p) && _isVideoUrl(_getUrl(p)))))
  readonly property bool _pipewireVideoActive: (Pipewire.linkGroups?.values ?? []).some(lg => lg?.source?.type === PwNodeType.VideoSource)
  readonly property var _videoExts: ["mp4", "mkv", "webm", "avi", "mov", "m4v", "mpeg", "mpg", "wmv", "flv"]
  readonly property var _videoHints: ["mpv", "vlc", "celluloid", "io.github.celluloid_player.celluloid", "org.gnome.totem", "smplayer", "mplayer", "haruna", "kodi", "io.github.iwalton3.jellyfin-media-player", "jellyfin", "plex"]
  readonly property var _videoPatterns: ["youtube.com/watch", "laracasts.com/", "youtu.be/", "netflix.com", "primevideo.com", "osnplus.com", "vimeo.com", "twitch.tv", "hulu.com", "disneyplus.com", "crunchyroll.com", "max.com", "hbomax.com"]
  readonly property MprisPlayer active: _selectActive()
  readonly property string activeDisplayName: active?.identity ?? (active ? "Unknown player" : "No player")
  readonly property string activeIconName: _iconFor(active)
  readonly property list<MprisPlayer> allPlayers: Mpris.players?.values.filter(p => p?.canControl !== undefined) ?? []
  readonly property bool anyVideoPlaying: _hasPlayingVideo || (_pipewireVideoActive && _activeIsVideo)
  readonly property bool canGoNext: active?.canGoNext ?? false
  readonly property bool canGoPrevious: active?.canGoPrevious ?? false
  readonly property bool canPause: active?.canPause ?? false
  readonly property bool canPlay: active?.canPlay ?? false
  readonly property bool canSeek: active?.canSeek ?? false
  readonly property bool hasActive: !!active
  readonly property bool hasPlayers: players.length > 0
  readonly property bool isPlaying: active?.isPlaying ?? false
  property MprisPlayer manualActive: null
  readonly property list<MprisPlayer> players: allPlayers.filter(p => p?.canControl)
  readonly property string trackAlbum: active?.trackAlbum ?? ""
  readonly property string trackArtUrl: active?.trackArtUrl ?? ""
  readonly property string trackArtist: active?.trackArtist ?? ""
  readonly property real trackLength: (active?.length ?? 0) < 9e12 ? (active?.length ?? 0) : 0
  readonly property string trackTitle: active?.trackTitle ?? ""

  function _getUrl(p) {
    return p?.metadata?.["xesam:url"] ?? p?.metadata?.["xesam:URL"] ?? "";
  }

  function _iconFor(p) {
    if (!p)
      return "audio-x-generic";
    const iconMap = {
      chrome: "google-chrome",
      "google chrome": "google-chrome",
      edge: "microsoft-edge",
      "microsoft edge": "microsoft-edge",
      firefox: "firefox",
      zen: "zen",
      brave: "brave-browser"
    };
    const src = (p.desktopEntry || p.identity || "").toLowerCase();
    for (const [key, icon] of Object.entries(iconMap))
      if (src.includes(key))
        return icon;
    return src.replace(/[^a-z0-9+.-]/g, "-") || "audio-x-generic";
  }

  function _isBrowserApp(p) {
    const src = String((p?.desktopEntry ?? "") + (p?.identity ?? "")).toLowerCase();
    return _browserHints.some(h => src.includes(h));
  }

  function _isVideoApp(p) {
    const src = String((p?.desktopEntry ?? "") + (p?.identity ?? "")).toLowerCase();
    return _videoHints.some(h => src.includes(h));
  }

  function _isVideoUrl(url) {
    if (!url)
      return false;
    const lower = String(url).toLowerCase();
    if (_audioOnlyPatterns.some(p => lower.includes(p)))
      return false;
    if (_videoPatterns.some(p => lower.includes(p)))
      return true;
    const match = lower.match(/\.([a-z0-9]{2,5})(?:\?|#|$)/);
    return !!(match && _videoExts.includes(match[1]));
  }

  function _selectActive() {
    if (manualActive && allPlayers.includes(manualActive))
      return manualActive;
    return players.find(p => p.playbackState === MprisPlaybackState.Playing) ?? players.find(p => p.canPlay) ?? players[0] ?? null;
  }

  function next() {
    active?.next();
  }

  function pause() {
    active?.pause();
  }

  function play() {
    active?.play();
  }

  function playPause() {
    active?.isPlaying ? active?.pause() : active?.play();
  }

  function previous() {
    active?.previous();
  }

  function seek(position) {
    if (!canSeek)
      return;
    const delta = position - active.position;
    if (Math.abs(delta) > 0.005)
      active.seek(delta);
  }

  function seekByRatio(ratio) {
    if (!canSeek || trackLength <= 0)
      return;
    const delta = ratio * trackLength - active.position;
    if (Math.abs(delta) > 0.005)
      active.seek(delta);
  }

  function stop() {
    active?.stop();
  }

  Connections {
    function onValuesChanged() {
      if (root.manualActive && !root.allPlayers.includes(root.manualActive))
        root.manualActive = null;
    }

    target: Mpris.players
  }
}
