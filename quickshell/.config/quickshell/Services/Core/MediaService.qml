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
  readonly property list<MprisPlayer> allPlayers: Mpris.players?.values.filter(p => p?.canControl !== undefined) ?? []
  readonly property bool anyVideoPlaying: hasPlayingVideo || (pipewireVideoActive && activeIsVideo)
  readonly property bool canGoNext: active?.canGoNext ?? false
  readonly property bool canGoPrevious: active?.canGoPrevious ?? false
  readonly property bool canPause: active?.canPause ?? false
  readonly property bool canPlay: active?.canPlay ?? false
  readonly property bool canSeek: active?.canSeek ?? false
  readonly property bool hasActive: !!active
  readonly property bool hasPlayers: players.length > 0
  readonly property bool hasPlayingVideo: players.some(p => p?.playbackState === MprisPlaybackState.Playing && logic.isVideo(p))
  readonly property bool isPlaying: active?.isPlaying ?? false
  property MprisPlayer manualActive: null
  readonly property bool pipewireVideoActive: (Pipewire.linkGroups?.values ?? []).some(lg => lg?.source?.type === PwNodeType.VideoSource)
  readonly property list<MprisPlayer> players: allPlayers.filter(p => p.canControl)
  readonly property string trackAlbum: active?.trackAlbum ?? ""
  readonly property string trackArtUrl: active?.trackArtUrl ?? ""
  readonly property string trackArtist: active?.trackArtist ?? ""
  readonly property real trackLength: (active?.length ?? 0) < 9e12 ? (active?.length ?? 0) : 0
  readonly property string trackTitle: active?.trackTitle ?? ""

  function _resolveActive() {
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
    if (canSeek && active)
      logic.safeSeek(active, position - active.position);
  }

  function seekByRatio(ratio) {
    if (canSeek && trackLength > 0 && active)
      logic.safeSeek(active, ratio * trackLength - active.position);
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

    function getUrl(player) {
      return player?.metadata?.["xesam:url"] ?? player?.metadata?.["xesam:URL"] ?? "";
    }

    function iconFor(player) {
      if (!player)
        return "audio-x-generic";
      const src = (player.desktopEntry || player.identity || "").toLowerCase();
      for (const key in iconMap)
        if (src.includes(key))
          return iconMap[key];
      return src.replace(/[^a-z0-9+.-]/g, "-") || "audio-x-generic";
    }

    function isVideo(player) {
      if (!player)
        return false;
      const id = (player.desktopEntry || player.identity || "").toLowerCase();
      if (videoHints.some(h => id.includes(h)))
        return true;

      if (!browserHints.some(h => id.includes(h)))
        return false;
      const url = getUrl(player).toLowerCase();
      if (!url || audioPatterns.some(ap => url.includes(ap)))
        return false;
      if (videoPatterns.some(vp => url.includes(vp)))
        return true;
      const match = url.match(/\.([a-z0-9]{2,5})(?:\?|#|$)/);
      return !!(match && videoExts.includes(match[1]));
    }

    function safeSeek(player, delta) {
      if (Math.abs(delta) > 0.005)
        player.seek(delta);
    }
  }
}
