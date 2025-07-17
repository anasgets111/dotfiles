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
  property bool busy: false
  property int updates: 0
  property double lastSync: 0
  property bool lastWasFull: false
  property int failureCount: 0
  property int failureThreshold: 3
  property int minuteMs : 60 * 1000
  property int pollInterval: 1 * minuteMs
  property int syncInterval: 5 * minuteMs


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
    stderr: StdioCollector { id: err }
    onExited: function(exitCode) {
      const stderrText = (err.text || "").trim()
      if (stderrText) console.warn("[UpdateChecker] stderr:", stderrText)

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

      // Only bump lastSync if last run was full and succeeded
      if (lastWasFull) {
        lastSync = Date.now()

      }
    }
  }





  function startUpdateProcess(cmd) {
    pkgProc.command = cmd
    pkgProc.running = true
    killTimer.restart()
  }

  function doPoll(forceFull = false) {
    if (busy) return
    busy = true

    const now = Date.now()
    const full = forceFull || (now - lastSync > syncInterval)
    lastWasFull = full



    if (full) {
      startUpdateProcess(["checkupdates", "--nocolor"])
    } else {
      startUpdateProcess(["checkupdates", "--nosync", "--nocolor"])
    }
  }

  Timer {
    id: pollTimer
    interval: pollInterval
    repeat: true
    onTriggered: doPoll()
  }

  Timer {
    id: killTimer
    interval: minuteMs
    repeat: false
    onTriggered: {
      if (pkgProc.running) {
        pkgProc.kill()
        busy = false
        notify("critical",
               qsTr("Update check killed"),
               qsTr("Process took too long"))
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
                 ? ""
                 : "󰂪" )
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        color: Theme.textContrast(
          hovered && !busy ? Theme.onHoverColor : Theme.inactiveColor
        )
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
        font.pixelSize: Theme.fontSize
        font.family:     Theme.fontFamily
        color: Theme.textContrast(
          hovered && !busy ? Theme.onHoverColor : Theme.inactiveColor
        )
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
