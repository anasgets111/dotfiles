pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

Singleton {
  id: root

  readonly property var _audioPatterns: ["music.youtube.com", "spotify.com", "soundcloud.com", "music.apple.com", "deezer.com", "tidal.com", "bandcamp.com", "pocketcasts.com", "audible.com", "mixcloud.com", "tunein.com"]
  readonly property var _browserHints: ["firefox", "zen", "chrome", "chromium", "brave", "vivaldi", "edge", "opera"]
  property bool _resumeAfterSeek: false
  property real _seekFallbackLength: 0
  property var _seekPlayer: null
  property int _seekTrackId: -1
  readonly property var _videoExts: ["mp4", "mkv", "webm", "avi", "mov", "m4v", "mpeg", "mpg", "wmv", "flv"]
  readonly property var _videoHints: ["mpv", "vlc", "celluloid", "io.github.celluloid_player.celluloid", "org.gnome.totem", "smplayer", "mplayer", "haruna", "kodi", "io.github.iwalton3.jellyfin-media-player", "jellyfin", "plex", "freetube", "stremio", "clapper", "dragon", "hypnotix"]
  readonly property var _videoPatterns: ["youtube.com/watch", "laracasts.com", "streamimdb.ru", "youtu.be", "netflix.com", "primevideo.com", "osnplus.com", "vimeo.com", "twitch.tv", "hulu.com", "disneyplus.com", "crunchyroll.com", "max.com", "hbomax.com", "udemy.com", "coursera.org", "pluralsight.com", "nebula.tv", "odysee.com", "dailymotion.com", "tv.apple.com", "tiktok.com", "instagram.com/reel", "meet.google.com", "teams.microsoft.com", "teams.live.com", "zoom.us", "discord.com", "meet.jit.si", "whereby.com", "webex.com", "gotomeeting.com"]
  readonly property MprisPlayer active: players.find(player => player.playbackState === MprisPlaybackState.Playing) ?? players.find(player => player.playbackState !== MprisPlaybackState.Stopped) ?? players.find(player => player.canPlay) ?? players[0] ?? null
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
  readonly property real trackLength: {
    const rawLength = active?.length;
    if (active?.lengthSupported && Number.isFinite(rawLength) && rawLength > 0 && rawLength < 9e12)
      return rawLength;
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
  function seekByRatio(positionRatio: real): void {
    if (trackLength <= 0 || !Number.isFinite(positionRatio))
      return;
    root.seek(Math.max(0, Math.min(1, positionRatio)) * trackLength);
  }
  function stop(): void {
    if (active?.canControl)
      active.stop();
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
