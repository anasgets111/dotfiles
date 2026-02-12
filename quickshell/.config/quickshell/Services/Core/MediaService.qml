pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

Singleton {
  id: root

  readonly property MprisPlayer active: _resolveActive()
  readonly property string activeDisplayName: active?.identity ?? (active ? "Unknown Player" : "No Player")
  readonly property string activeIconName: logic.iconFor(active)
  readonly property bool activeIsVideo: logic.isVideo(active)
  readonly property bool anyVideoPlaying: hasPlayingVideo || (pipewireVideoActive && activeIsVideo)
  readonly property bool canGoNext: active?.canGoNext ?? false
  readonly property bool canGoPrevious: active?.canGoPrevious ?? false
  readonly property bool canPause: active?.canPause ?? false
  readonly property bool canPlay: active?.canPlay ?? false
  readonly property bool canSeek: active?.canSeek ?? false
  readonly property bool hasActive: !!active
  readonly property bool hasPlayers: players.length > 0
  readonly property bool hasPlayingVideo: players.some(player => player?.playbackState === MprisPlaybackState.Playing && logic.isVideo(player))
  readonly property bool isPlaying: active?.isPlaying ?? false
  readonly property bool pipewireVideoActive: (Pipewire.linkGroups?.values ?? []).some(linkGroup => linkGroup?.state === PwLinkState.Active && (linkGroup?.source?.type & PwNodeType.VideoSource) === PwNodeType.VideoSource)
  readonly property list<MprisPlayer> players: Mpris.players?.values.filter(player => player?.canControl !== undefined && player.canControl) ?? []
  readonly property string trackAlbum: active?.trackAlbum ?? ""
  readonly property string trackArtUrl: active?.trackArtUrl ?? ""
  readonly property string trackArtist: active?.trackArtist ?? ""
  readonly property real trackLength: (active?.length ?? 0) < 9e12 ? (active?.length ?? 0) : 0
  readonly property string trackTitle: active?.trackTitle ?? ""

  function _resolveActive(): var {
    return players.find(player => player.playbackState === MprisPlaybackState.Playing) ?? players.find(player => player.canPlay) ?? players[0] ?? null;
  }

  function next(): void {
    active?.next();
  }

  function pause(): void {
    active?.pause();
  }

  function play(): void {
    active?.play();
  }

  function playPause(): void {
    active?.isPlaying ? active?.pause() : active?.play();
  }

  function previous(): void {
    active?.previous();
  }

  function seek(position: real): void {
    if (canSeek && active)
      logic.safeSeek(active, position - active.position);
  }

  function seekByRatio(positionRatio: real): void {
    if (canSeek && trackLength > 0 && active)
      logic.safeSeek(active, positionRatio * trackLength - active.position);
  }

  function stop(): void {
    active?.stop();
  }

  PwObjectTracker {
    objects: Pipewire.linkGroups?.values ?? []
  }

  QtObject {
    id: logic

    readonly property var audioPatterns: ["music.youtube.com", "spotify.com", "soundcloud.com", "music.apple.com", "deezer.com", "tidal.com", "bandcamp.com", "pocketcasts.com", "audible.com", "mixcloud.com", "tunein.com"]
    readonly property var browserHints: ["firefox", "zen", "chrome", "chromium", "brave", "vivaldi", "edge", "opera"]
    readonly property var iconMap: ({
        "chrome": "google-chrome",
        "google chrome": "google-chrome",
        "edge": "microsoft-edge",
        "microsoft edge": "microsoft-edge",
        "firefox": "firefox",
        "zen": "zen",
        "brave": "brave-browser",
        "vivaldi": "vivaldi"
      })
    readonly property var videoExts: ["mp4", "mkv", "webm", "avi", "mov", "m4v", "mpeg", "mpg", "wmv", "flv"]
    readonly property var videoHints: ["mpv", "vlc", "celluloid", "io.github.celluloid_player.celluloid", "org.gnome.totem", "smplayer", "mplayer", "haruna", "kodi", "io.github.iwalton3.jellyfin-media-player", "jellyfin", "plex", "freetube", "stremio", "clapper", "dragon", "hypnotix"]
    readonly property var videoPatterns: ["youtube.com/watch", "laracasts.com/", "youtu.be/", "netflix.com", "primevideo.com", "osnplus.com", "vimeo.com", "twitch.tv", "hulu.com", "disneyplus.com", "crunchyroll.com", "max.com", "hbomax.com", "udemy.com", "coursera.org", "pluralsight.com", "nebula.tv", "odysee.com", "dailymotion.com", "tv.apple.com", "tiktok.com", "instagram.com/reel"]

    function getUrl(player: var): string {
      return player?.metadata?.["xesam:url"] ?? player?.metadata?.["xesam:URL"] ?? "";
    }

    function iconFor(player: var): string {
      if (!player)
        return "audio-x-generic";
      const sourceText = (player.desktopEntry || player.identity || "").toLowerCase();
      for (const iconKey in iconMap)
        if (sourceText.includes(iconKey))
          return iconMap[iconKey];
      return sourceText.replace(/[^a-z0-9+.-]/g, "-") || "audio-x-generic";
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
      if (Math.abs(deltaPosition) > 0.005)
        player.seek(deltaPosition);
    }
  }
}
