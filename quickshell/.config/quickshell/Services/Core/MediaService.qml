pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

Singleton {
  id: root

  readonly property var videoAppHints: ["mpv", "vlc", "celluloid", "io.github.celluloid_player.celluloid", "org.gnome.totem", "smplayer", "mplayer", "haruna", "kodi", "io.github.iwalton3.jellyfin-media-player", "jellyfin", "plex"]
  readonly property var browserAppHints: ["firefox", "zen", "chrome", "chromium", "brave", "vivaldi", "edge", "opera"]
  readonly property var audioOnlyPatterns: ["music.youtube.com", "spotify.com", "soundcloud.com", "music.apple.com", "deezer.com", "tidal.com", "bandcamp.com"]
  readonly property var videoPatterns: ["youtube.com/watch", "youtu.be/", "netflix.com", "primevideo.com", "osnplus.com", "vimeo.com", "twitch.tv", "hulu.com", "disneyplus.com", "crunchyroll.com", "max.com", "hbomax.com"]
  readonly property var videoFileExts: ["mp4", "mkv", "webm", "avi", "mov", "m4v", "mpeg", "mpg", "wmv", "flv"]

  readonly property bool pipewireVideoActive: hasActiveVideoStreams()

  readonly property list<MprisPlayer> allPlayers: Mpris.players ? Mpris.players.values : []
  readonly property list<MprisPlayer> players: allPlayers.filter(playerObj => playerObj?.canControl)
  readonly property MprisPlayer active: selectActivePlayer()
  readonly property string activeDisplayName: active ? (active.identity || "Unknown player") : "No player"
  readonly property string activeIconName: iconNameForPlayer(active)
  readonly property bool anyVideoPlaying: allPlayers.some(playerObj => playerObj && playerObj.playbackState === MprisPlaybackState.Playing && (isVideoApp(playerObj) || (isBrowserApp(playerObj) && isVideoUrl(getMetadataUrl(playerObj)))))

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
  property int selectedPlayerIndex: -1
  property string trackAlbum: active?.trackAlbum ?? ""
  property string trackArtUrl: active?.trackArtUrl ?? ""
  property string trackArtist: active?.trackArtist ?? ""
  property real trackLength: active && active.length < infiniteTrackLength ? active.length : 0
  property string trackTitle: active?.trackTitle ?? ""

  function hasActiveVideoStreams() {
    return Pipewire.nodes?.values?.some(nodeObj => nodeObj?.isStream && (String(nodeObj.properties["media.class"] || "").toLowerCase().includes("video") || ["movie", "video"].includes(String(nodeObj.properties["media.role"] || "").toLowerCase()))) || false;
  }

  function isVideoUrl(urlString) {
    if (!urlString)
      return false;
    const lowerUrl = String(urlString).toLowerCase();
    if (audioOnlyPatterns.some(pattern => lowerUrl.includes(pattern)))
      return false;
    if (videoPatterns.some(pattern => lowerUrl.includes(pattern)))
      return true;
    const match = lowerUrl.match(/\.([a-z0-9]{2,5})(?:\?|#|$)/);
    return !!(match && videoFileExts.includes(match[1]));
  }

  function appMatches(playerObj, hintsList) {
    if (!playerObj)
      return false;
    const desktopEntry = String(playerObj.desktopEntry || "").toLowerCase();
    const identity = String(playerObj.identity || "").toLowerCase();
    const list = Array.isArray(hintsList) ? hintsList : [];
    return list.some(hint => desktopEntry.includes(hint) || identity.includes(hint));
  }
  function isBrowserApp(playerObj) {
    return appMatches(playerObj, browserAppHints);
  }
  function isVideoApp(playerObj) {
    return appMatches(playerObj, videoAppHints);
  }

  function getMetadataUrl(playerObj) {
    return String(playerObj?.metadata["xesam:url"] || playerObj?.metadata["xesam:URL"] || "");
  }

  function selectActivePlayer() {
    if (manualActive && isValidPlayer(manualActive))
      return manualActive;
    if (selectedPlayerIndex >= 0 && selectedPlayerIndex < players.length)
      return players[selectedPlayerIndex];
    return players.find(player => player.playbackState === MprisPlaybackState.Playing) || players.find(player => player.canControl && player.canPlay) || players[0] || null;
  }

  function iconNameForPlayer(playerObj) {
    if (!playerObj)
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
    const desktopEntry = canonical(playerObj.desktopEntry || "");
    if (desktopEntry)
      return normalize(desktopEntry) || "audio-x-generic";
    const identity = canonical(playerObj.identity || "");
    return normalize(identity) || "audio-x-generic";
  }

  function isValidPlayer(playerObj) {
    return !!playerObj && allPlayers.includes(playerObj);
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
  function playerKey(playerObj) {
    return playerObj ? (playerObj.desktopEntry || playerObj.busName || playerObj.identity || "") : "";
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
      const pos = ratio * trackLength;
      active.position = pos;
      currentPosition = pos;
    }
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
    target: Mpris.players
    function onValuesChanged() {
      if (root.selectedPlayerIndex >= root.players.length)
        root.selectedPlayerIndex = -1;
      if (root.manualActive && !root.allPlayers.includes(root.manualActive))
        root.manualActive = null;
    }
  }
}
