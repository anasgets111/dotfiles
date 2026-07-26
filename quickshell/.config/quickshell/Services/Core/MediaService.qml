pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

Singleton {
  id: root

  readonly property var _audioPatterns: ["music.youtube.com", "spotify.com", "soundcloud.com", "music.apple.com", "deezer.com", "tidal.com", "bandcamp.com", "pocketcasts.com", "audible.com", "mixcloud.com", "tunein.com"]
  readonly property var _browserHints: ["firefox", "zen", "chrome", "chromium", "brave", "vivaldi", "edge", "opera"]
  property string _cachedArtUrl: ""
  property string _cachedTrackKey: ""
  property real _cachedTrackLength: 0
  property bool _resumeAfterSeek: false
  property real _seekFallbackLength: 0
  property var _seekPlayer: null
  property int _seekTrackId: -1
  property int _selectedPlayerId: -1
  readonly property var _videoExts: ["mp4", "mkv", "webm", "avi", "mov", "m4v", "mpeg", "mpg", "wmv", "flv"]
  readonly property var _videoHints: ["mpv", "vlc", "celluloid", "io.github.celluloid_player.celluloid", "org.gnome.totem", "smplayer", "mplayer", "haruna", "kodi", "io.github.iwalton3.jellyfin-media-player", "jellyfin", "plex", "freetube", "stremio", "clapper", "dragon", "hypnotix"]
  readonly property var _videoPatterns: ["youtube.com/watch", "laracasts.com", "streamimdb.ru", "youtu.be", "netflix.com", "primevideo.com", "osnplus.com", "vimeo.com", "twitch.tv", "hulu.com", "disneyplus.com", "crunchyroll.com", "max.com", "hbomax.com", "udemy.com", "coursera.org", "pluralsight.com", "nebula.tv", "odysee.com", "dailymotion.com", "tv.apple.com", "tiktok.com", "instagram.com/reel", "meet.google.com", "teams.microsoft.com", "teams.live.com", "zoom.us", "discord.com", "meet.jit.si", "whereby.com", "webex.com", "gotomeeting.com"]
  readonly property MprisPlayer active: players.find(player => player.uniqueId === root._selectedPlayerId) ?? players.find(player => player.playbackState === MprisPlaybackState.Playing) ?? players.find(player => player.playbackState !== MprisPlaybackState.Stopped) ?? players.find(player => player.canPlay) ?? players[0] ?? null
  readonly property bool anyVideoPlaying: hasPlayingVideo || (pipewireVideoActive && _isVideo(active))
  readonly property bool canGoNext: active?.canGoNext ?? false
  readonly property bool canGoPrevious: active?.canGoPrevious ?? false
  readonly property bool canSeek: active?.canSeek ?? false
  readonly property bool canTogglePlaying: active?.canTogglePlaying ?? false
  readonly property bool hasPlayingVideo: players.some(player => player.playbackState === MprisPlaybackState.Playing && _isVideo(player))
  readonly property bool pipewireVideoActive: (Pipewire.linkGroups?.values ?? []).some(linkGroup => linkGroup?.state === PwLinkState.Active && (linkGroup?.source?.type & PwNodeType.VideoSource) === PwNodeType.VideoSource)
  readonly property bool playbackAvailable: !!active && active.playbackState !== MprisPlaybackState.Stopped
  readonly property list<MprisPlayer> players: Mpris.players?.values.filter(player => !!player?.canControl) ?? []
  readonly property bool playing: active?.isPlaying ?? false
  readonly property string trackArtUrl: {
    const player = active;
    return player?.trackArtUrl || (player && _trackKey(player) === _cachedTrackKey ? _cachedArtUrl : "");
  }
  readonly property real trackLength: {
    const metadataLength = _metadataTrackLength(active);
    if (metadataLength)
      return metadataLength;
    if (active && _trackKey(active) === _cachedTrackKey)
      return _cachedTrackLength;
    const length = active?.length;
    if (active?.lengthSupported && Number.isFinite(length) && length > 0 && length < 9e12)
      return length;
    // Zen temporarily invalidates length metadata after SetPosition.
    return active && active === _seekPlayer && active.uniqueId === _seekTrackId ? _seekFallbackLength : 0;
  }

  function _isVideo(player: var): bool {
    if (!player)
      return false;
    const playerIdentifier = (player.desktopEntry || player.identity || "").toLowerCase();
    if (_videoHints.some(videoHint => playerIdentifier.includes(videoHint)))
      return true;
    if (!_browserHints.some(browserHint => playerIdentifier.includes(browserHint)))
      return false;
    const mediaUrl = (player.metadata?.["xesam:url"] ?? player.metadata?.["xesam:URL"] ?? "").toLowerCase();
    if (!mediaUrl || _audioPatterns.some(audioPattern => mediaUrl.includes(audioPattern)))
      return false;
    if (_videoPatterns.some(videoPattern => mediaUrl.includes(videoPattern)))
      return true;
    const extensionMatch = mediaUrl.match(/\.([a-z0-9]{2,5})(?:\?|#|$)/);
    return !!(extensionMatch && _videoExts.includes(extensionMatch[1]));
  }
  function _metadataTrackLength(player: var): real {
    const lengthUs = Number(player?.metadata?.["mpris:length"]);
    return Number.isFinite(lengthUs) && lengthUs > 0 && lengthUs <= Number.MAX_SAFE_INTEGER ? lengthUs / 1e6 : 0;
  }
  function _refreshTrackCache(): void {
    const player = active;
    const trackKey = _trackKey(player);
    if (trackKey !== _cachedTrackKey) {
      _cachedTrackKey = trackKey;
      _cachedArtUrl = "";
      _cachedTrackLength = 0;
    }
    // Zen can omit mpris:artUrl and mpris:length in later updates for the same track.
    const artUrl = player?.trackArtUrl ?? "";
    if (artUrl)
      _cachedArtUrl = artUrl;
    const length = _metadataTrackLength(player);
    if (length)
      _cachedTrackLength = length;
  }
  function _trackKey(player: var): string {
    if (!player)
      return "";
    return JSON.stringify([player.dbusName, player.metadata?.["xesam:url"] ?? "", player.trackTitle]);
  }
  function next(): void {
    if (canGoNext)
      active.next();
  }
  function pause(): void {
    if (active?.canPause)
      active.pause();
  }
  function play(): void {
    if (active?.canPlay)
      active.play();
  }
  function playPause(): void {
    if (canTogglePlaying)
      active.togglePlaying();
  }
  function previous(): void {
    if (canGoPrevious)
      active.previous();
  }
  function seek(position: real): void {
    if (!canSeek || !active?.positionSupported || !Number.isFinite(position))
      return;
    const player = active;
    const target = trackLength > 0 ? Math.max(0, Math.min(trackLength, position)) : Math.max(0, position);
    const delta = target - player.position;
    if (!Number.isFinite(delta) || Math.abs(delta) <= 0.005)
      return;
    root._seekFallbackLength = root.trackLength;
    root._seekPlayer = player;
    root._seekTrackId = player.uniqueId;
    root._resumeAfterSeek = player.isPlaying;
    player.position = target;
    if (root._resumeAfterSeek)
      seekResume.restart();
  }
  function seekBy(offset: real): void {
    if (!canSeek || !Number.isFinite(offset) || offset === 0)
      return;
    active.seek(offset);
  }
  function seekByRatio(positionRatio: real): void {
    if (trackLength <= 0 || !Number.isFinite(positionRatio))
      return;
    root.seek(Math.max(0, Math.min(1, positionRatio)) * trackLength);
  }
  function selectNextPlayer(): void {
    if (players.length < 2)
      return;
    const currentIndex = players.findIndex(player => player.uniqueId === root.active?.uniqueId);
    root._selectedPlayerId = players[(currentIndex + 1) % players.length].uniqueId;
  }
  function stop(): void {
    if (active?.canControl)
      active.stop();
  }

  onActiveChanged: _refreshTrackCache()

  Connections {
    function onMetadataChanged(): void {
      root._refreshTrackCache();
    }

    target: root.active
  }
  PwObjectTracker {
    objects: Pipewire.linkGroups?.values ?? []
  }
  Timer {
    id: seekResume

    interval: 100

    onTriggered: if (root._resumeAfterSeek && root._seekPlayer?.canPlay)
      root._seekPlayer.play()
  }
}
