pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Services.SystemInfo
import qs.Services
import qs.Services.Core
import qs.Services.Utils
import qs.Components

// Minimal top bar scaffold: one layer-surface per screen, top-anchored with reserved space.
Scope {
  id: barRoot

  // Create a bar per connected screen
  Variants {
    model: Quickshell.screens

    WlrLayershell {
      id: layer

      required property var modelData

      anchors.left: true
      anchors.right: true

      // Position across the top edge
      anchors.top: true
      color: "#991e1e2e"
      exclusionMode: ExclusionMode.Auto

      // Bar height (tweak as desired)
      implicitHeight: 36

      // Top layer suitable for panels
      layer: WlrLayer.Top

      // Optional: namespace for external tools
      namespace: "qs-bar"
      // Bind to this screen
      screen: layer.modelData

      // Reserve space so tiled windows avoid the bar
      // Simple clipboard test button next to record toggle
      Rectangle {
        id: clipboardBtn

        anchors.right: recordToggle.left
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 9
        border.color: "#ffffff80"
        border.width: 1
        color: "#5c6bc0"
        implicitHeight: 23
        implicitWidth: 100
        radius: 4

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          onClicked: clipboardPopup.open()
        }
      }

      // Minimal popup showing cliphist items; no wl-copy integration here
      PopupWindow {
        id: clipboardPopup

        // Model for list
        property var itemsModel: []

        function close() {
          visible = false;
        }

        function open() {
          refresh();
          visible = true;
        }

        function refresh() {
          ClipboardLiteService.list(function (lines) {
            itemsModel = lines;
          }, 30);
        }

        anchor.rect.x: clipboardBtn.x + clipboardBtn.width - width
        anchor.rect.y: layer.height
        // Position relative to this bar window, under the bar near the button
        anchor.window: layer
        implicitHeight: 300
        implicitWidth: 420
        visible: false

        // Live update when service emits changes (delete/wipe/copies by other sources)
        Connections {
          function onChanged() {
            if (clipboardPopup.visible) {
              Logger.log("ClipboardTest", "service changed -> refresh");
              clipboardPopup.refresh();
            }
          }

          target: ClipboardLiteService
        }

        // Poll for updates while visible to emulate live updates using only the lite service
        Timer {
          id: clipboardPoll

          interval: 1200 // ms
          repeat: true
          running: clipboardPopup.visible

          onTriggered: clipboardPopup.refresh()
        }

        // Popup content container
        Rectangle {
          anchors.fill: parent
          border.color: "#ffffff30"
          border.width: 1
          color: "#1e1e2e"

          // Header controls and list below
          // Header
          Text {
            id: headerText

            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 8
            color: "#fff"
            font.bold: true
            text: "Clipboard (cliphist)"
          }

          Rectangle {
            id: closeBtn

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 8
            border.color: "#ffffff30"
            border.width: 1
            color: "#455a64"
            height: 24
            radius: 4
            width: 60

            MouseArea {
              anchors.fill: parent

              onClicked: clipboardPopup.close()
            }

            Text {
              anchors.centerIn: parent
              color: "#fff"
              font.pixelSize: 12
              text: "Close"
            }
          }

          Rectangle {
            id: refreshBtn

            anchors.right: closeBtn.left
            anchors.rightMargin: 6
            anchors.top: parent.top
            anchors.topMargin: 8
            border.color: "#ffffff30"
            border.width: 1
            color: "#3949ab"
            height: 24
            radius: 4
            width: 70

            MouseArea {
              anchors.fill: parent

              onClicked: clipboardPopup.refresh()
            }

            Text {
              anchors.centerIn: parent
              color: "#fff"
              font.pixelSize: 12
              text: "Refresh"
            }
          }

          Rectangle {
            id: wipeBtn

            anchors.right: refreshBtn.left
            anchors.rightMargin: 6
            anchors.top: parent.top
            anchors.topMargin: 8
            border.color: "#ffffff30"
            border.width: 1
            color: "#8e24aa"
            height: 24
            radius: 4
            width: 60

            MouseArea {
              anchors.fill: parent

              onClicked: ClipboardLiteService.wipe(function () {})
            }

            Text {
              anchors.centerIn: parent
              color: "#fff"
              font.pixelSize: 12
              text: "Wipe"
            }
          }

          // List
          ListView {
            id: list

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 6
            anchors.right: parent.right
            anchors.top: headerText.bottom
            clip: true
            model: clipboardPopup.itemsModel

            delegate: Rectangle {
              id: delegateRoot

              required property int index
              required property var modelData

              border.color: "#ffffff12"
              border.width: 1
              color: delegateRoot.index % 2 ? "#2a2a3a" : "#242436"
              height: Math.max(28, textItem.implicitHeight + 10)
              width: list.width

              Text {
                id: textItem

                anchors.fill: parent
                anchors.margins: 6
                color: "#eee"
                elide: Text.ElideRight
                text: delegateRoot.modelData
              }

              MouseArea {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                anchors.fill: parent

                onClicked: function (mouse) {
                  if (mouse.button === Qt.LeftButton) {
                    var picked = String(delegateRoot.modelData || "");
                    clipboardPopup.close();
                    ClipboardLiteService.copyAndPasteFromLine(picked, {
                      primary: false,
                      delayMs: 200
                    }, function (ok) {});
                  } else if (mouse.button === Qt.RightButton) {
                    Logger.log("ClipboardTest", "delete attempt for:", delegateRoot.modelData);
                    ClipboardLiteService.deleteFromLine(delegateRoot.modelData, function (ok) {
                      Logger.log("ClipboardTest", "delete result:", ok);
                    });
                  }
                }
              }
            }
          }
        }
      }

      // Placeholder background; replace with real content later
      // Simple recording toggle button
      Rectangle {
        id: recordToggle

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 9
        border.color: "#ffffff80"
        border.width: 1
        color: ScreenRecordingService.isRecording ? "#e53935" : "#43a047"
        implicitHeight: 23
        implicitWidth: 80
        radius: 4

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          onClicked: ScreenRecordingService.toggleRecording()
        }
      }

      WindowTitle {
        anchors.centerIn: parent
      }

      Text {
        id: statusText

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: "#FFFFFF"
        font.bold: true
        padding: 12
        text: TimeService.currentTime + " - " + TimeService.currentDate + " - " + MainService.username + " - " + TimeService.formatDuration(SystemInfoService.uptime)
      }

      Rectangle {
        id: idleToggleRect

        anchors.left: statusText.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        color: IdleService.enabled ? "#FF5722" : "#4CAF50"  // Orange when inhibited, green when not
        height: 20
        radius: 4
        width: 30

        // on clicked it should report idle status
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor

          onClicked: {
            IdleService.toggle();
            Logger.log("Bar", "Idle status changed:", IdleService.enabled);
          }
        }
      }
    }
  }
}
