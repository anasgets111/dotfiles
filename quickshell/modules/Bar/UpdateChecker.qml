import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var updateCommand: [
    "xdg-terminal-exec",
    "--title=Global Updates",
    "-e",
    "/home/anas/.config/waybar/update.sh"
  ]
  property bool hovered: false
  property string updateIcon: ""
  property string noUpdateIcon: "󰂪"

  property bool busy: false
  property int updates: 0
  property double lastSync: 0

  property int failureCount: 0
  property int failureThreshold: 3

  property int pollInterval: 5  * 60 * 1000
  property int syncInterval: 30 * 60 * 1000

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(
    Theme.itemWidth,
    indicator.implicitWidth
      + (updateCount.visible ? updateCount.implicitWidth : 0)
  )

  function notify(urgency, title, body) {
    Quickshell.execDetached([
      "notify-send", "-u", urgency, title, body
    ])
  }

  Process {
    id: pkgProc
    stdout: StdioCollector { id: out }
    onExited: function(exitCode) {
      if (!pkgProc.running && !busy) return;
      killTimer.stop()
      busy = false

      const raw = (out.text || "").trim()
      const list = raw ? raw.split(/\r?\n/) : []
      const count = list.length

      if (exitCode !== 0 && exitCode !== 2) {
        failureCount++
        if (failureCount >= failureThreshold) {
          notify("critical", "Update check failed",
                 "Exit code: " + exitCode + " (failed " + failureCount + " times)")
          failureCount = 0
        }
        updates = 0
        return
      }

      failureCount = 0

      if (count > updates) {
        const msg = count === 1
          ? "One package can be upgraded"
          : count + " packages can be upgraded";

        notify("normal", "Updates Available", msg)
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

  Timer {
    id: killTimer
    interval: 60000
    repeat: false
    onTriggered: {
      if (pkgProc.running && busy) {
        pkgProc.running = false
        busy = false
        notify("critical", "Update check killed", "Process took too long")
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.itemRadius
    color: hovered && !busy ? Theme.onHoverColor : Theme.inactiveColor

    RowLayout {
      id: row
      anchors.centerIn: parent
      spacing: 4

      Text {
        id: indicator
        text: busy
              ? ""
              : (updates > 0
                 ? updateIcon
                 : noUpdateIcon)
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        color: hovered && !busy ? Theme.textOnHoverColor : Theme.textContrast(Theme.inactiveColor)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

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
        color: hovered && !busy ? Theme.textOnHoverColor : Theme.textContrast(Theme.inactiveColor)
        Layout.alignment:   Qt.AlignVCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: hovered = true
      onExited: hovered = false
      onClicked: {
        if (busy) return;
        if (updates > 0) {
          Quickshell.execDetached(updateCommand)
        } else {
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
