import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
  id: root
  // command to run when clicked (e.g. ["sh", "/path/to/myscript.sh"])
  property var updateCommand: [
    "xdg-terminal-exec",
    "--title=Global Updates",
    "-e",
    "/home/anas/.config/waybar/update.sh"
  ]



  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(
    Theme.itemWidth,
    icon.implicitWidth
      + (updateCount.visible ? updateCount.implicitWidth : 0)
      + row.spacing
      + 12
  )
  visible: true

  // Unicode or font-glyphs for your icons
  property string updateIcon: ""     // FontAwesome: fa-download
  property string noUpdateIcon: "󰂪"   // FontAwesome: fa-check

  // single-process + single-timer approach
  property bool busy: false
  property double lastSync: 0
  property bool hasUpdates: false
  property int updates: 0
  property int pollInterval: 5 * 60 * 1000      // 5 minutes
  property int syncInterval: 60 * 60 * 1000     // 1 hour

  Process {
    id: pkgProc
    // Called after each run (offline or sync)
    onExited: {
      busy = false
      // exitCode 2 → DB stale, re-run full sync once
      if (exitCode === 2) {
        if (command.includes("--nosync")) {
          lastSync = Date.now()
          busy = true
          command = ["checkupdates"]
          running = true
          return
        } else {
          // sync itself failed
          hasUpdates = false; updates = 0;
          return
        }
      }
      // parse stdout lines
      let list = stdout.text.trim()
        ? stdout.text.trim().split("\n")
        : []
      let count = list.length
      // notify only on 0→>0
      if (count > 0 && !hasUpdates) {
        Quickshell.execDetached([
          "notify-send","-u","normal",
          "Updates Available",
          count + " packages can be upgraded"
        ])
      }
      hasUpdates = (count > 0)
      updates    = count
    }
  }

  Timer {
    id: pollTimer
    interval: pollInterval; repeat: true; running: true
    onTriggered: {
      if (busy) return
      busy = true
      let now = Date.now()
      if (now - lastSync > syncInterval) {
        // time for a full sync
        pkgProc.command = ["checkupdates"]
        lastSync = now
      } else {
        // fast offline check
        pkgProc.command = ["checkupdates", "--nosync"]
      }
      pkgProc.running = true
    }
  }

  // Visual indicator + click handler
  Rectangle {
    anchors.fill: parent
    radius: Theme.itemRadius
    color: Theme.inactiveColor

    RowLayout {
      id: row
      anchors.centerIn: parent
      anchors.verticalCenter: parent.verticalCenter

      Text {
        id: icon
        text: root.hasUpdates
              ? root.updateIcon
              : root.noUpdateIcon
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        color: Theme.textContrast(Theme.inactiveColor)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Layout.alignment:
          Qt.AlignHCenter | Qt.AlignVCenter
      }

      // Show number of updates if available
      Text {
        id: updateCount
        visible: root.hasUpdates
        text: root.updates
        font.pixelSize: Theme.fontSize * 0.9
        font.family: Theme.fontFamily
        color: Theme.textContrast(Theme.inactiveColor)
        verticalAlignment: Text.AlignVCenter
        Layout.alignment: Qt.AlignVCenter
        leftPadding: 4
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (updateService.hasUpdates
            && updateCommand.length > 0) {
          Quickshell.execDetached(updateCommand)
        } else {
          // trigger manual poll
          syncProc.running = true
        }
      }
    }
  }

  Component.onCompleted: pollTimer.start()
}
