//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

ShellRoot {
  id: root

  // ── Theme ─────────────────────────────────────────────────────────
  QtObject {
    id: theme
    readonly property color activeColor: "#cba6f7"
    readonly property color bgColor: "#1e1e2e"
    readonly property color bgInput: withOpacity(bgColor, 0.85)
    readonly property color critical: "#f38ba8"
    readonly property color warning: "#fab387"
    readonly property color textActiveColor: "#cdd6f4"
    readonly property string fontFamily: "CaskaydiaCove Nerd Font Propo"
    readonly property string iconFontFamily: "JetBrainsMono Nerd Font Mono"
    readonly property int fontHero: 58
    readonly property int fontXl: 20
    readonly property int fontLg: 16
    readonly property int fontMd: 14
    readonly property int fontSm: 12
    readonly property int iconSizeMd: 18
    readonly property int iconSizeSm: 14
    readonly property int controlHeightLg: 42
    readonly property int radiusFull: 9999
    readonly property int radiusMd: 12
    readonly property int radiusXl: 40
    readonly property int spacingSm: 8
    readonly property int spacingMd: 12
    readonly property int spacingLg: 16
    readonly property int spacingXl: 24
    readonly property int shadowBlurLg: 32
    readonly property color shadowColor: withOpacity("#000000", 0.55)
    readonly property int animationDuration: 147
    function withOpacity(color, opacity) {
      const c = Qt.color(color);
      return Qt.rgba(c.r, c.g, c.b, opacity);
    }
  }

  // ── State ─────────────────────────────────────────────────────────
  QtObject {
    id: greeterState
    property int currentSessionIndex: 0
    property string pamState: ""
    property string passwordBuffer: ""
    property var sessionExecs: []
    property var sessionList: []
    property var sessionPaths: []
    property bool unlocking: false
    property string username: ""
    property string displayName: ""
    function reset() {
      username = ""; displayName = "";
      passwordBuffer = ""; pamState = "";
    }
  }

  // ── Memory ────────────────────────────────────────────────────────
  QtObject {
    id: greeterMemory
    readonly property string cacheDir: Quickshell.env("GREETER_CACHE_DIR") || "/var/cache/obelisk-greeter"
    property string lastSessionId: ""
    property string lastSuccessfulUser: ""
    property bool ready: false

    function load() {
      try {
        const data = JSON.parse(memoryFile.text());
        lastSessionId = data.lastSessionId ?? "";
        lastSuccessfulUser = data.lastSuccessfulUser ?? "";
      } catch (e) { console.warn("Failed to parse greeter memory:", e); }
    }
    function save() { memoryFile.setText(JSON.stringify({ lastSessionId, lastSuccessfulUser }, null, 2)); }
    function setLastSession(id) { lastSessionId = id ?? ""; save(); }
    function setLastUser(name) { lastSuccessfulUser = name ?? ""; save(); }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", cacheDir])
  }

  FileView {
    id: memoryFile
    atomicWrites: true; blockLoading: false; blockWrites: false
    path: greeterMemory.cacheDir + "/memory.json"
    printErrors: false; watchChanges: false
    onLoadFailed: greeterMemory.ready = true
    onLoaded: { greeterMemory.load(); greeterMemory.ready = true; }
  }

  // ── Surface ───────────────────────────────────────────────────────
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: surface
      required property var modelData
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.layer: WlrLayer.Overlay
      color: "transparent"
      screen: modelData
      anchors { bottom: true; left: true; right: true; top: true }

      GreeterContent {
        anchors.fill: parent
        isPrimary: !Quickshell.screens?.length || surface.screen?.name === Quickshell.screens[0]?.name
      }

      // Dev: Ctrl+Q to quit when not under greetd
      Shortcut {
        enabled: !Quickshell.env("GREETER_CACHE_DIR")
        sequence: "Ctrl+Q"
        onActivated: Qt.quit()
      }
    }
  }
}
