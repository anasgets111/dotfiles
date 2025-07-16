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

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(
    Theme.itemWidth,
    icon.implicitWidth
      + (updateCount.visible ? updateCount.implicitWidth : 0)
      + row.spacing
      + 12
  )
  visible: true

  property string updateIcon: ""
  property string noUpdateIcon: "󰂪"
  property bool busy: false
  property double lastSync: 0
  property bool hasUpdates: false
  property int updates: 0
  property int pollInterval: 5  * 60 * 1000
  property int syncInterval: 30 * 60 * 1000

  Process {
    id: pkgProc
    onExited: function(exitCode, status) {
      busy = false
      if (exitCode === 2) {
        if (command.includes("--nosync")) {
          lastSync = Date.now()
          busy = true
          command = ["checkupdates"]
          running = true
          return
        } else {
          hasUpdates = false; updates = 0;
          return
        }
      }
      if (exitCode !== 0 && exitCode !== 2) {
        Quickshell.execDetached(
          ["notify-send","-u","critical",
           "Update check failed","Exit code: "+exitCode]
        );
      }
      let list = (stdout && stdout.text && stdout.text.trim())
        ? stdout.text.trim().split("\n")
        : []
      let count = list.length
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
    interval: pollInterval
    repeat: true
    running: false
    onTriggered: {
      if (busy) {
        return
      }
      busy = true
      let now = Date.now()
      if (now - lastSync > syncInterval) {
        console.log("[UpdateChecker] Full sync branch: running 'checkupdates'")
        pkgProc.command = ["checkupdates"]
        lastSync = now
      } else {
        console.log("[UpdateChecker] Nosync branch: running 'checkupdates --nosync'")
        pkgProc.command = ["checkupdates", "--nosync"]
      }
      pkgProc.running = true
      killTimer.start()
    }
  }

  // Kill-switch timer to guard against hung pkgProc process
  Timer {
    id: killTimer
    interval: 60000 // 15 seconds, adjust as needed
    repeat: false
    running: false
    onTriggered: {
      if (pkgProc.running) {
        pkgProc.running = false
        busy = false
        Quickshell.execDetached([
          "notify-send", "-u", "critical",
          "Update check killed", "Process took too long"
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
      anchors.verticalCenter: parent.verticalCenter
      Text {
        id: icon
        visible: !root.busy
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
      Text {
        id: busyIndicator
        visible: root.busy
        text: "" // Nerd Font gear icon
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        color: Theme.textContrast(Theme.inactiveColor)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        RotationAnimator on rotation {
          running: root.busy
          from: 0
          to: 360
          duration: 800
          loops: Animation.Infinite
        }
      }
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
      enabled: !root.busy
      onClicked: {
        if (root.hasUpdates
            && updateCommand.length > 0) {
          Quickshell.execDetached(updateCommand)
        } else {
          let now = Date.now()
          if (now - lastSync > syncInterval) {
            console.log("[UpdateChecker] Full sync branch (manual): running 'checkupdates'")
            pkgProc.command = ["checkupdates"]
            lastSync = now
          } else {
            console.log("[UpdateChecker] Nosync branch (manual): running 'checkupdates --nosync'")
            pkgProc.command = ["checkupdates", "--nosync"]
          }
          busy = true
          pkgProc.running = true
          killTimer.start()
        }
      }
    }
  }
  Component.onCompleted: {
    pollTimer.start()
  }
}
