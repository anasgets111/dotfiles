pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

Singleton {
  id: root

  readonly property MprisPlayer active: players.find(player => player.playbackState === MprisPlaybackState.Playing) ?? players.find(player => player.canPlay) ?? players[0] ?? null
  readonly property bool activeIsVideo: logic.isVideo(active)
  readonly property bool anyVideoPlaying: hasPlayingVideo || (pipewireVideoActive && activeIsVideo)
  readonly property bool canGoNext: active?.canGoNext ?? false
  readonly property bool canGoPrevious: active?.canGoPrevious ?? false
  readonly property bool canPause: active?.canPause ?? false
  readonly property bool canPlay: active?.canPlay ?? false
  readonly property bool canSeek: active?.canSeek ?? false
  readonly property bool canTogglePlaying: active?.canTogglePlaying ?? false
  readonly property bool hasActive: !!active
  readonly property bool hasPlayingVideo: players.some(player => player?.playbackState === MprisPlaybackState.Playing && logic.isVideo(player))
  readonly property bool isPlaying: active?.isPlaying ?? false
  readonly property bool pipewireVideoActive: (Pipewire.linkGroups?.values ?? []).some(linkGroup => linkGroup?.state === PwLinkState.Active && (linkGroup?.source?.type & PwNodeType.VideoSource) === PwNodeType.VideoSource)
  readonly property list<MprisPlayer> players: Mpris.players?.values.filter(player => !!player?.canControl) ?? []
  readonly property string trackAlbum: active?.trackAlbum ?? ""
  readonly property string trackArtUrl: active?.trackArtUrl ?? ""
  readonly property string trackArtist: active?.trackArtist ?? ""
  readonly property real trackLength: {
    if (!active?.lengthSupported)
      return 0;
    const rawLength = active?.length ?? 0;
    return Number.isFinite(rawLength) && rawLength > 0 && rawLength < 9e12 ? rawLength : 0;
  }
  readonly property string trackTitle: active?.trackTitle ?? ""

  function next(): void {
    if (canGoNext)
      active.next();
  }

  function pause(): void {
    if (canPause)
      active.pause();
  }

  function play(): void {
    if (canPlay)
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
    const target = trackLength > 0 ? Math.max(0, Math.min(trackLength, position)) : Math.max(0, position);
    logic.safeSeek(active, target - active.position);
  }

  function seekByRatio(positionRatio: real): void {
    if (!canSeek || !active?.positionSupported || !active?.lengthSupported || trackLength <= 0 || !Number.isFinite(positionRatio))
      return;
    const ratio = Math.max(0, Math.min(1, positionRatio));
    logic.safeSeek(active, ratio * trackLength - active.position);
  }

  function stop(): void {
    if (active?.canControl)
      active.stop();
  }

  PwObjectTracker {
    objects: Pipewire.linkGroups?.values ?? []
  }

  QtObject {
    id: logic

    readonly property var audioPatterns: ["music.youtube.com", "spotify.com", "soundcloud.com", "music.apple.com", "deezer.com", "tidal.com", "bandcamp.com", "pocketcasts.com", "audible.com", "mixcloud.com", "tunein.com"]
    readonly property var browserHints: ["firefox", "zen", "chrome", "chromium", "brave", "vivaldi", "edge", "opera"]
    readonly property var videoExts: ["mp4", "mkv", "webm", "avi", "mov", "m4v", "mpeg", "mpg", "wmv", "flv"]
    readonly property var videoHints: ["mpv", "vlc", "celluloid", "io.github.celluloid_player.celluloid", "org.gnome.totem", "smplayer", "mplayer", "haruna", "kodi", "io.github.iwalton3.jellyfin-media-player", "jellyfin", "plex", "freetube", "stremio", "clapper", "dragon", "hypnotix"]
    readonly property var videoPatterns: ["youtube.com/watch", "laracasts.com", "streamimdb.ru", "youtu.be", "netflix.com", "primevideo.com", "osnplus.com", "vimeo.com", "twitch.tv", "hulu.com", "disneyplus.com", "crunchyroll.com", "max.com", "hbomax.com", "udemy.com", "coursera.org", "pluralsight.com", "nebula.tv", "odysee.com", "dailymotion.com", "tv.apple.com", "tiktok.com", "instagram.com/reel", "meet.google.com", "teams.microsoft.com", "teams.live.com", "zoom.us", "discord.com", "meet.jit.si", "whereby.com", "webex.com", "gotomeeting.com"]

    function getUrl(player: var): string {
      return player?.metadata?.["xesam:url"] ?? player?.metadata?.["xesam:URL"] ?? "";
    }

    function isVideo(player: var): bool {
      if (!player)
        return false;
      const playerIdentifier = (player.desktopEntry || player.identity || "").toLowerCase();
      if (videoHints.some(videoHint => playerIdentifier.includes(videoHint)))
        return true;

      if (!browserHints.some(browserHint => playerIdentifier.includes(browserHint)))
        return false;
      const mediaUrl = getUrl(player).toLowerCase();
      if (!mediaUrl || audioPatterns.some(audioPattern => mediaUrl.includes(audioPattern)))
        return false;
      if (videoPatterns.some(videoPattern => mediaUrl.includes(videoPattern)))
        return true;
      const extensionMatch = mediaUrl.match(/\.([a-z0-9]{2,5})(?:\?|#|$)/);
      return !!(extensionMatch && videoExts.includes(extensionMatch[1]));
    }

    function safeSeek(player: var, deltaPosition: real): void {
      if (Number.isFinite(deltaPosition) && Math.abs(deltaPosition) > 0.005)
        player.seek(deltaPosition);
    }
  }
}
