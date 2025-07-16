import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
  id: root

  // ── Commands & icons ─────────────────────────────────────────────────────────
  property var updateCommand: [
    "xdg-terminal-exec",
    "--title=Global Updates",
    "-e",
    "/home/anas/.config/waybar/update.sh"
  ]
  property string updateIcon: ""
  property string noUpdateIcon: "󰂪"

  // ── State ───────────────────────────────────────────────────────────────────
  property bool busy: false
  property bool hasUpdates: false
  property int updates: 0
  property double lastSync: 0

  // ── Timing (ms) ─────────────────────────────────────────────────────────────
  property int pollInterval: 5  * 60 * 1000
  property int syncInterval: 30 * 60 * 1000

  // ── Size & visibility ──────────────────────────────────────────────────────
  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(
    Theme.itemWidth,
    indicator.implicitWidth
      + (updateCount.visible ? updateCount.implicitWidth : 0)
      + row.spacing
      + 12
  )


  Process {
    id: pkgProc

    onExited: function(exitCode) {
      busy = false

      if (exitCode !== 0) {
        Quickshell.execDetached([
          "notify-send", "-u", "critical",
          "Update check failed",
          "Exit code: " + exitCode
        ])
        hasUpdates = false
        updates = 0
        return
      }

      const list = (pkgProc.output || "")
        .trim()
        .split(/\r?\n/)
        .filter(s => s.length)
      const count = list.length

      if (count > 0 && !hasUpdates) {
        Quickshell.execDetached([
          "notify-send", "-u", "normal",
          "Updates Available",
          count + " packages can be upgraded"
        ])
      }

      hasUpdates = count > 0
      updates    = count
    }
  }

  function doPoll(forceFull = false) {
    if (busy) return
    busy = true

    const now = Date.now()
    const full = forceFull || (now - lastSync > syncInterval)
    pkgProc.command = full
      ? ["checkupdates", "--nocolor"]
      : ["checkupdates", "--nosync", "--nocolor"]
    if (full) lastSync = now

    pkgProc.running = true
    killTimer.restart()
  }

  Timer {
    id: pollTimer
    interval: pollInterval
    repeat: true
    onTriggered: doPoll()
  }

  // guard against hung pkgProc
  Timer {
    id: killTimer
    interval: 60000    // 60 seconds
    repeat: false
    onTriggered: {
      if (pkgProc.running) {
        pkgProc.running = false
        busy = false
        Quickshell.execDetached([
          "notify-send", "-u", "critical",
          "Update check killed",
          "Process took too long"
        ])
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.itemRadius
    color: Theme.inactiveColor

    RowLayout {
      id: row
      anchors.centerIn: parent

      Text {
        id: indicator
        // Always visible – switches glyph based on busy/hasUpdates
        text: root.busy
              ? ""  // Nerd-font gear
              : (root.hasUpdates
                 ? root.updateIcon
                 : root.noUpdateIcon)
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        color: Theme.textContrast(Theme.inactiveColor)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

        // spin when busy
        RotationAnimator on rotation {
            from: 0
            to:   360
            duration: 800
            loops: Animation.Infinite
            running: root.busy
            onStopped: indicator.rotation = 0
        }
      }

      Text {
        id: updateCount
        visible: root.hasUpdates
        text:    root.updates
        font.pixelSize: Theme.fontSize * 0.9
        font.family:     Theme.fontFamily
        color: Theme.textContrast(Theme.inactiveColor)
        Layout.alignment:   Qt.AlignVCenter
        leftPadding: 4
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (root.busy) return;
        if (root.hasUpdates) {
          Quickshell.execDetached(updateCommand)
        } else {
          // force a full sync and reuse doPoll logic
          doPoll(true);
        }
      }
    }
  }

  Component.onCompleted: {
    doPoll()
    pollTimer.start()
  }
}
