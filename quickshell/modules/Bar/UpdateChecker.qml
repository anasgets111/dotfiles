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

  // Unicode or font-glyphs for your icons
  property string updateIcon: ""     // FontAwesome: fa-download
  property string noUpdateIcon: "󰂪"   // FontAwesome: fa-check

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(
    Theme.itemWidth,
    icon.implicitWidth
      + (updateCount.visible ? updateCount.implicitWidth : 0)
      + row.spacing
      + 12
  )
  visible: true

  // Service object to manage state
  QtObject {
    id: updateService
    property bool hasUpdates: false
    property int updates: 0

    function poll() {
      checkProc.running = true
    }

    function handle(lines) {
      var count = (lines && lines[0] !== "") ? lines.length : 0
      // notify only on transition from 0→>0
      if (count > 0 && !hasUpdates) {
        Quickshell.execDetached([
          "notify-send", "-u", "normal",
          "Updates Available",
          count + " packages can be upgraded"
        ])
      }
      hasUpdates = (count > 0)
      updates = count
    }
  }

  // Run 'checkupdates' and collect stdout (offline poll)
  Process {
    id: checkProc
    command: ["checkupdates", "--nosync"]
    stdout: StdioCollector {
      onStreamFinished: {
        var arr = text.trim()
          ? text.trim().split("\n")
          : []
        updateService.handle(arr)
      }
    }
  }

  // Run 'checkupdates' to sync the temporary database (hourly)
  Process {
    id: syncProc
    command: ["checkupdates"]
    stdout: StdioCollector {
      onStreamFinished: {
        // No need to handle output for sync
      }
    }
  }

  // Poll every 5 minutes
  Timer {
    interval: 5 * 60 * 1000
    repeat: true
    running: true
    onTriggered: updateService.poll()
  }

  // Sync every hour
  Timer {
    interval: 60 * 60 * 1000
    repeat: true
    running: true
    onTriggered: syncProc.running = true
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
        text: updateService.hasUpdates
              ? updateIcon
              : noUpdateIcon
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
        visible: updateService.hasUpdates
        text: updateService.updates
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

  Component.onCompleted: {
    updateService.poll()
  }
}
