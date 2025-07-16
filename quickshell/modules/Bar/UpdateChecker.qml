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
      + 12
  )

  // ── Functions ──────────────────────────────────────────────────────────────
  function notify(urgency, title, body) {
    Quickshell.execDetached([
      "notify-send", "-u", urgency, title, body
    ])
  }


  Process {
    id: pkgProc

    onExited: function(exitCode) {
      busy = false

      if (exitCode !== 0) {
        notify("critical", "Update check failed", "Exit code: " + exitCode)
        updates = 0
        return
      }

      const list = (pkgProc.output || "")
        .trim()
        .split(/\r?\n/)
        .filter(Boolean)
      const count = list.length

      if (count > 0 && updates === 0) {
        notify("normal", "Updates Available", count + " packages can be upgraded")
      }

      updates = count
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
    onTriggered: {
      if (pkgProc.running) {
        pkgProc.running = false
        busy = false
        notify("critical", "Update check killed", "Process took too long")
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
        // Always visible – switches glyph based on busy/updates
        text: busy
              ? ""  // Nerd-font gear
              : (updates > 0
                 ? updateIcon
                 : noUpdateIcon)
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
            running: busy
            onStopped: indicator.rotation = 0
        }
      }

      Text {
        id: updateCount
        visible: updates > 0
        text:    updates
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
        if (busy) return;
        if (updates > 0) {
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
