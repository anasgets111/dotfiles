pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io

Item {
  id: root

  property bool busy: false
  property color effectiveBg: (root.hovered && !root.busy) ? Theme.onHoverColor : Theme.inactiveColor
  property color effectiveFg: Theme.textContrast(effectiveBg)
  property int failureCount: 0
  property int failureThreshold: 3
  property bool hovered: false
  property int lastNotifiedUpdates: 0
  property double lastSync: 0
  property bool lastWasFull: false
  property int minuteMs: 60 * 1000
  property int pollInterval: 1 * minuteMs
  property string rawOutput: ""
  property int syncInterval: 5 * minuteMs
  property var updateCommand: ["xdg-terminal-exec", "--title='Global Updates'", "-e", "sh", "-c", "$BIN/update.sh"]
  property var updatePackages: []
  property int updates: 0

  function doPoll(forceFull = false) {
    if (busy)
      return;

    busy = true;
    const now = Date.now();
    const full = forceFull || (now - lastSync > syncInterval);
    lastWasFull = full;
    if (full)
      startUpdateProcess(["checkupdates", "--nocolor"]);
    else
      startUpdateProcess(["checkupdates", "--nosync", "--nocolor"]);
  }
  function notify(urgency, title, body) {
    notifyProc.command = ["notify-send", "-u", urgency, "-A", "update=Update Now", "-w", title, body];
    notifyProc.running = true;
  }
  function runUpdate() {
    if (busy)
      return;

    if (updates > 0)
      Quickshell.execDetached(root.updateCommand);
    else
      doPoll(true);
  }
  function startUpdateProcess(cmd) {
    pkgProc.command = cmd;
    pkgProc.running = true;
    killTimer.interval = lastWasFull ? 60 * 1000 : minuteMs;
    killTimer.restart();
  }

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, row.implicitWidth + (2 * Theme.itemRadius), busyMeasureRow.implicitWidth + (2 * Theme.itemRadius))

  Component.onCompleted: {
    // Initialize from cache
    if (cache.cachedUpdatePackages && cache.cachedUpdatePackages.length) {
      root.updatePackages = cache.cachedUpdatePackages;
      root.updates = cache.cachedUpdatePackages.length;
    }
    if (cache.cachedLastSync && cache.cachedLastSync > 0) {
      root.lastSync = cache.cachedLastSync;
    }

    doPoll();
    pollTimer.start();
  }

  PersistentProperties {
    id: cache

    property double cachedLastSync: 0
    property var cachedUpdatePackages: []

    reloadableId: "ArchCheckerCache"
  }
  Process {
    id: notifyProc

    stdout: StdioCollector {
      id: notifyOut

    }

    onExited: function (exitCode, exitStatus) {
      var act = (notifyOut.text || "").trim();
      if (act === "update")
        root.runUpdate();
    }
  }
  Process {
    id: pkgProc

    stderr: StdioCollector {
      id: err

    }
    stdout: StdioCollector {
      id: out

    }

    onExited: function (exitCode, exitStatus) {
      const stderrText = (err.text || "").trim();
      if (stderrText)
        console.warn("[UpdateChecker] stderr:", stderrText);

      if (!pkgProc.running && !root.busy)
        return;

      killTimer.stop();
      root.busy = false;
      const raw = (out.text || "").trim();
      root.rawOutput = raw;
      const list = raw ? raw.split(/\r?\n/) : [];
      root.updates = list.length;
      var pkgs = [];
      for (var i = 0; i < list.length; ++i) {
        var m = list[i].match(/^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/);
        if (m)
          pkgs.push({
            "name": m[1],
            "oldVersion": m[2],
            "newVersion": m[3]
          });
      }
      root.updatePackages = pkgs;
      if (exitCode !== 0 && exitCode !== 2) {
        root.failureCount++;
        if (root.failureCount >= root.failureThreshold) {
          root.notify("critical", "Update check failed", "Exit code: " + exitCode + " (failed " + root.failureCount + " times)");
          root.failureCount = 0;
        }
        root.updates = 0;
        root.updatePackages = [];
        return;
      }
      root.failureCount = 0;

      if (root.updates > root.lastNotifiedUpdates) {
        const added = root.updates - root.lastNotifiedUpdates;
        const msg = added === 1 ? "One new package can be upgraded (" + root.updates + " total)" : added + " new packages can be upgraded (" + root.updates + " total)";
        root.notify("normal", "Updates Available", msg, true);
        root.lastNotifiedUpdates = root.updates;
      }
      // Reset the lastNotifiedUpdates whenever count drops to 0, regardless of sync type
      if (root.updates === 0) {
        root.lastNotifiedUpdates = 0;
      }

      if (root.lastWasFull) {
        root.lastSync = Date.now();
      }

      cache.cachedUpdatePackages = root.updatePackages;
      cache.cachedLastSync = root.lastSync;
    }
  }
  Timer {
    id: pollTimer

    interval: root.pollInterval
    repeat: true

    onTriggered: root.doPoll()
  }
  Timer {
    id: killTimer

    interval: root.minuteMs
    repeat: false

    onTriggered: {
      if (pkgProc.running) {
        root.busy = false;
        root.notify("critical", qsTr("Update check killed"), qsTr("Process took too long"));
      }
    }
  }
  Rectangle {
    anchors.centerIn: parent
    color: root.effectiveBg
    height: implicitHeight
    implicitHeight: Math.max(row.implicitHeight, Theme.itemHeight)
    implicitWidth: Math.max(row.implicitWidth, busyMeasureRow.implicitWidth) + (Theme.itemRadius)
    radius: Theme.itemRadius
    width: implicitWidth

    MouseArea {
      id: mouseArea

      anchors.fill: parent
      cursorShape: root.busy ? Qt.BusyCursor : Qt.PointingHandCursor
      hoverEnabled: true

      onClicked: {
        if (root.busy)
          return;

        if (root.updates > 0)
          Quickshell.execDetached(root.updateCommand);
        else
          root.doPoll(true);
      }
      onEntered: root.hovered = true
      onExited: root.hovered = false
    }
    RowLayout {
      id: row

      anchors.centerIn: parent
      spacing: 4

      Text {
        id: indicator

        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        Layout.preferredHeight: Theme.itemHeight
        color: root.effectiveFg
        elide: Text.ElideNone
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        text: root.busy ? "" : root.updates > 0 ? "" : "󰂪"
        verticalAlignment: Text.AlignVCenter
      }
      Item {
        id: updateCountWrap

        Layout.alignment: Qt.AlignVCenter
        Layout.preferredHeight: Theme.itemHeight
        Layout.preferredWidth: updateCount.implicitWidth
        visible: root.updates > 0

        Text {
          id: updateCount

          anchors.verticalCenter: parent.verticalCenter
          color: root.effectiveFg
          elide: Text.ElideNone
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          text: root.updates
        }
      }
    }
    RowLayout {
      id: busyMeasureRow

      spacing: 4
      visible: false

      Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: ""
      }
    }
    Rectangle {
      id: tooltip

      anchors.left: mouseArea.left
      anchors.top: mouseArea.bottom
      anchors.topMargin: 8
      color: Theme.onHoverColor
      height: tooltipText.height + 8
      opacity: mouseArea.containsMouse ? 1 : 0
      radius: Theme.itemRadius
      visible: mouseArea.containsMouse && !root.busy
      width: tooltipText.width + 16

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.OutCubic
        }
      }

      Column {
        id: tooltipText

        anchors.centerIn: parent
        spacing: 4

        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          text: root.updates === 0 ? qsTr("No updates available") : root.updates === 1 ? qsTr("One package can be upgraded:") : root.updates + qsTr(" packages can be upgraded:")
        }
        Repeater {
          model: root.updatePackages

          delegate: Text {
            required property var model

            color: Theme.textContrast(Theme.onHoverColor)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: model.name + ": " + model.oldVersion + " → " + model.newVersion
          }
        }
      }
    }
  }
}
