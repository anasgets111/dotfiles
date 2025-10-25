pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

Singleton {
  id: root

  readonly property MprisPlayer active: selectActivePlayer()
  readonly property string activeDisplayName: active?.identity || (active ? "Unknown player" : "No player")
  readonly property string activeIconName: iconNameForPlayer(active)
  readonly property list<MprisPlayer> allPlayers: Mpris.players?.values.filter(p => isAlivePlayer(p)) || []
  readonly property bool anyVideoPlaying: (players.some(p => p?.playbackState === MprisPlaybackState.Playing && (isVideoApp(p) || (isBrowserApp(p) && isVideoUrl(p?.metadata["xesam:url"] || p?.metadata["xesam:URL"] || ""))))) || (pipewireVideoActive && active && (isVideoApp(active) || (isBrowserApp(active) && (active.metadata["xesam:url"] || active.metadata["xesam:URL"]))))
  readonly property var audioOnlyPatterns: ["music.youtube.com", "spotify.com", "soundcloud.com", "music.apple.com", "deezer.com", "tidal.com", "bandcamp.com"]
  readonly property var browserAppHints: ["firefox", "zen", "chrome", "chromium", "brave", "vivaldi", "edge", "opera"]
  property bool canGoNext: active?.canGoNext ?? false
  property bool canGoPrevious: active?.canGoPrevious ?? false
  property bool canPause: active?.canPause ?? false
  property bool canPlay: active?.canPlay ?? false
  property bool canSeek: active?.canSeek ?? false
  property real currentPosition: 0
  readonly property bool hasActive: !!active
  readonly property bool hasPlayers: players.length > 0
  property bool isPlaying: active?.isPlaying ?? false
  property string lastActiveKey: ""
  property MprisPlayer manualActive: null
  readonly property bool pipewireVideoActive: (Pipewire.linkGroups?.values || []).some(lg => lg?.source?.type === PwNodeType.VideoSource)
  readonly property list<MprisPlayer> players: allPlayers.filter(p => p?.canControl ?? false)
  property int selectedPlayerIndex: -1
  property string trackAlbum: active?.trackAlbum ?? ""
  property string trackArtUrl: active?.trackArtUrl ?? ""
  property string trackArtist: active?.trackArtist ?? ""
  property real trackLength: (active && active.length < 922337203685) ? active.length : 0
  property string trackTitle: active?.trackTitle ?? ""
  readonly property var videoAppHints: ["mpv", "vlc", "celluloid", "io.github.celluloid_player.celluloid", "org.gnome.totem", "smplayer", "mplayer", "haruna", "kodi", "io.github.iwalton3.jellyfin-media-player", "jellyfin", "plex"]
  readonly property var videoFileExts: ["mp4", "mkv", "webm", "avi", "mov", "m4v", "mpeg", "mpg", "wmv", "flv"]
  readonly property var videoPatterns: ["youtube.com/watch", "youtu.be/", "netflix.com", "primevideo.com", "osnplus.com", "vimeo.com", "twitch.tv", "hulu.com", "disneyplus.com", "crunchyroll.com", "max.com", "hbomax.com"]

  function appMatches(p, hints) {
    if (!p)
      return false;
    const entry = String(p.desktopEntry || "").toLowerCase();
    const id = String(p.identity || "").toLowerCase();
    return hints.some(hint => entry.includes(hint) || id.includes(hint));
  }

  function iconNameForPlayer(p) {
    if (!p)
      return "audio-x-generic";
    const iconMap = {
      "chrome": "google-chrome",
      "google chrome": "google-chrome",
      "edge": "microsoft-edge",
      "microsoft edge": "microsoft-edge",
      "firefox": "firefox",
      "zen": "zen",
      "brave": "brave-browser"
    };
    const normalize = s => String(s).toLowerCase().replace(/[^a-z0-9+.-]/g, "-");
    const canonical = str => {
      const lower = String(str || "").toLowerCase();
      for (const key in iconMap)
        if (lower.includes(key))
          return iconMap[key];
      return str;
    };
    return normalize(canonical(p.desktopEntry) || canonical(p.identity)) || "audio-x-generic";
  }

  // ===== Helper Functions =====
  function isAlivePlayer(p) {
    if (!p)
      return false;
    if (typeof p.isValid === "function")
      return p.isValid();
    try {
      return p.canControl !== undefined || !!p.dbusName;
    } catch (e) {
      return false;
    }
  }

  function isBrowserApp(p) {
    return appMatches(p, browserAppHints);
  }

  function isVideoApp(p) {
    return appMatches(p, videoAppHints);
  }

  function isVideoUrl(url) {
    if (!url)
      return false;
    const lower = String(url).toLowerCase();
    if (audioOnlyPatterns.some(p => lower.includes(p)))
      return false;
    if (videoPatterns.some(p => lower.includes(p)))
      return true;
    const match = lower.match(/\.([a-z0-9]{2,5})(?:\?|#|$)/);
    return !!(match && videoFileExts.includes(match[1]));
  }

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

  function playerKey(p) {
    return p ? (p.desktopEntry || p.dbusName || p.identity || "") : "";
  }

  function previous() {
    if (active && canGoPrevious)
      active.previous();
  }

  function seek(position) {
    if (!active?.canSeek)
      return;
    const delta = position - active.position;
    if (Math.abs(delta) > 0.005)
      active.seek(delta);
    currentPosition = position;
  }

  function seekByRatio(ratio) {
    if (!active?.canSeek || trackLength <= 0)
      return;
    const target = ratio * trackLength;
    const delta = target - active.position;
    if (Math.abs(delta) > 0.005)
      active.seek(delta);
    currentPosition = target;
  }

  function selectActivePlayer() {
    if (manualActive && isAlivePlayer(manualActive) && allPlayers.includes(manualActive))
      return manualActive;
    if (selectedPlayerIndex >= 0 && selectedPlayerIndex < players.length)
      return players[selectedPlayerIndex];
    return players.find(p => p.playbackState === MprisPlaybackState.Playing) || players.find(p => p.canControl && p.canPlay) || players[0] || null;
  }

  function stop() {
    if (active)
      active.stop();
  }

  onActiveChanged: {
    currentPosition = 0;
    const key = playerKey(active);
    if (key && key !== lastActiveKey)
      lastActiveKey = key;
  }

  Connections {
    function onValuesChanged() {
      if (root.selectedPlayerIndex >= root.players.length)
        root.selectedPlayerIndex = -1;
      if (root.manualActive && !root.allPlayers.includes(root.manualActive))
        root.manualActive = null;
    }

    target: Mpris.players
  }
}
