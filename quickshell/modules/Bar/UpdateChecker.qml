import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Window

Item {
  id: root
  property var updateCommand: [
    "xdg-terminal-exec",
    "--title=Global Updates",
    "-e",
    "/home/anas/.config/waybar/update.sh"
  ]
  property bool hovered: false
  property bool popupHovered: false
  property bool busy: false
  property int updates: 0
  property var updatePackages: []
  property string rawOutput: ""
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
  function runUpdate() {
    if (busy) return
    if (updates > 0) {
      Quickshell.execDetached(updateCommand)
    } else {
      doPoll(true)
    }
  }

  Process {
    id: notifyProc
    stdout: StdioCollector { id: notifyOut }

    onExited: {
      var act = (notifyOut.text || "").trim()
      if (act === "update") {
        runUpdate()
      }
    }
  }

  function notify(urgency, title, body) {
    notifyProc.command = [
      "notify-send",
      "-u", urgency,
      "-A", "update=Update Now",
      "-w",
      title,
      body
    ]
    notifyProc.running = true
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
      rawOutput = raw
      const list = raw ? raw.split(/\r?\n/) : []
      updates = list.length
      var pkgs = []
      for (var i = 0; i < list.length; ++i) {
        var m = list[i].match(/^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/)
        if (m) {
          pkgs.push({
            name: m[1],
            oldVersion: m[2],
            newVersion: m[3]
          })
        }
      }
      updatePackages = pkgs
      if (exitCode !== 0 && exitCode !== 2) {
        failureCount++
        if (failureCount >= failureThreshold) {
          notify("critical", "Update check failed",
                 "Exit code: " + exitCode + " (failed " + failureCount + " times)")
          failureCount = 0
        }
        updates = 0
        updatePackages = []
        return
      }
      failureCount = 0
      if (updates > 0 ) {
        const msg = updates === 1
          ? "One package can be upgraded"
          : updates + " packages can be upgraded";
        notify("normal", "Updates Available", msg)
      }
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
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
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
    RowLayout {
      id: row
      anchors.centerIn: parent
      spacing: 4
      Text {
        id: indicator
        text: busy ? "" : updates > 0 ? "" : "󰂪"
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
    // Popup {
    //   id: updateTooltip
    //   anchorItem: indicator
    //   visible: hovered && !busy
    //   implicitWidth: Math.min(400, column.implicitWidth + 16)
    //   implicitHeight: Math.min(300, column.implicitHeight + 16)
    //   contentItem: Rectangle {
    //     implicitWidth: column.implicitWidth + 16
    //     implicitHeight: column.implicitHeight + 16
    //     color: Theme.bgColor
    //     radius: Theme.itemRadius
    //     Column {
    //       id: column
    //       anchors.fill: parent
    //       anchors.margins: 8
    //       spacing: 4
    //       Text {
    //         visible: updates === 0
    //         color: Theme.textContrast(Theme.bgColor)
    //         text: busy
    //           ? qsTr("Checking for updates…")
    //           : qsTr("No updates available")
    //       }
    //       Text {
    //         visible: updates > 0
    //         font.family: Theme.fontFamily
    //         font.pixelSize: Theme.fontSize
    //         color: Theme.textActiveColor
    //         textFormat: Text.PlainText
    //         text: root.rawOutput
    //       }
    //     }
    //   }
    // }
  }
  Component.onCompleted: {
    doPoll()
    pollTimer.start()
  }
}
