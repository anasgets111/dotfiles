pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Config

/**
 * CounterPanel - A popup panel version of CounterDisplay
 * Opens as a popup panel instead of a standalone window
 */
LazyLoader {
  id: root

  property int panelWidth: 300
  property int panelHeight: 400

  property bool useButtonPosition: false
  property point buttonPosition: Qt.point(0, 0)
  property int buttonWidth: 0
  property int buttonHeight: 0

  property bool isOpen: false

  signal panelClosed

  // Keep the component alive to preserve state (Process, ListModel, etc.)
  active: true
  loading: true

  function openAt(x, y) {
    buttonPosition = Qt.point(x, y);
    buttonWidth = 0;
    buttonHeight = 0;
    open();
  }

  function openAtItem(item, mouseX, mouseY) {
    if (!item)
      return;
    buttonPosition = item.mapToItem(null, mouseX || 0, mouseY || 0);
    buttonWidth = item.width;
    buttonHeight = item.height;
    open();
  }

  function open() {
    useButtonPosition = true;
    isOpen = true;
  }

  function close() {
    if (!isOpen)
      return;
    isOpen = false;
    panelClosed();
  }

  PanelWindow {
    id: panel

    readonly property bool isClosing: !root.isOpen && visible

    color: "transparent"
    visible: root.isOpen || isClosing

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "counter-panel"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    // Clickthrough mask - when closed, make everything clickthrough
    mask: Region {
      item: maskItem
      intersection: root.isOpen ? Intersection.Combine : Intersection.Xor
    }

    // Dummy item for mask - when Xor, everything becomes clickthrough
    Item {
      id: maskItem
      anchors.fill: parent
    }

    anchors {
      top: true
      left: true
      right: true
      bottom: true
    }

    ListModel {
      id: linesModel
    }

    property bool userScrolledUp: false

    Process {
      id: counterProcess

      command: ["/bin/bash", Qt.resolvedUrl("../scripts/counter.sh").toString().replace("file://", "")]
      running: false

      stdout: SplitParser {
        onRead: data => {
          const line = data.trim();
          if (line !== "") {
            linesModel.append({
              lineText: line
            });
            if (!panel.userScrolledUp) {
              listView.positionViewAtEnd();
            }
          }
        }
      }

      onRunningChanged: {
        if (!running) {
          console.log("Counter process stopped");
        }
      }
    }

    function calculateX() {
      if (!root.useButtonPosition)
        return 0;
      const centerX = root.buttonPosition.x + root.buttonWidth / 2 - panelBackground.width / 2;
      const minX = 8;
      const maxX = panel.width - panelBackground.width - 8;
      return Math.max(minX, Math.min(centerX, maxX));
    }

    function calculateY() {
      if (!root.useButtonPosition)
        return Math.round((panel.height - panelBackground.height) / 2);
      const belowY = Theme.panelHeight;
      const aboveY = root.buttonPosition.y - panelBackground.height - 4;
      const maxY = panel.height - panelBackground.height - 8;

      if (belowY + panelBackground.height <= panel.height - 8)
        return Math.round(belowY);
      if (aboveY >= 8)
        return Math.round(aboveY);
      return Math.round(Math.min(belowY, maxY));
    }

    Shortcut {
      sequences: ["Escape"]
      enabled: root.isOpen
      onActivated: root.close()
      context: Qt.WindowShortcut
    }

    MouseArea {
      id: dismissArea
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      hoverEnabled: false
      enabled: root.isOpen

      onPressed: function (mouse) {
        if (!panelBackground)
          return;
        const local = panelBackground.mapFromItem(dismissArea, mouse.x, mouse.y);
        const inside = local.x >= 0 && local.y >= 0 && local.x <= panelBackground.width && local.y <= panelBackground.height;

        if (inside) {
          mouse.accepted = false;
          return;
        }

        root.close();
      }
    }

    Item {
      id: clipContainer
      anchors.fill: parent
      anchors.topMargin: Theme.panelHeight
      clip: true

      Rectangle {
        id: panelBackground

        readonly property real targetY: panel.calculateY() - Theme.panelHeight

        width: root.panelWidth
        height: root.panelHeight

        color: Theme.bgColor
        radius: Theme.itemRadius

        x: panel.calculateX()
        y: root.isOpen ? targetY : -height

        Behavior on y {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutCubic
          }
        }

        Column {
          anchors.fill: parent
          anchors.margins: Theme.baseScale * 8
          spacing: Theme.baseScale * 8

          ListView {
            id: listView

            width: parent.width
            height: parent.height - runButton.height - parent.spacing
            clip: true

            model: linesModel
            spacing: Theme.baseScale * 4

            onContentYChanged: {
              const atBottom = listView.atYEnd || (listView.contentHeight - listView.contentY - listView.height) < 10;
              panel.userScrolledUp = !atBottom;
            }

            ScrollBar.vertical: ScrollBar {
              policy: ScrollBar.AsNeeded
              width: 6
            }

            delegate: Item {
              id: lineItem
              required property string lineText

              width: listView.width
              height: lineText ? Theme.fontSize + Theme.baseScale * 4 : 0

              Text {
                anchors.fill: parent
                anchors.leftMargin: Theme.baseScale * 4
                text: lineItem.lineText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.textActiveColor
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
              }
            }
          }

          Rectangle {
            id: runButton

            width: parent.width
            height: Theme.baseScale * 36
            radius: Theme.itemRadius
            color: counterProcess.running ? Theme.activeColor : Theme.bgColor
            border.width: 1
            border.color: counterProcess.running ? Theme.activeColor : Theme.borderColor

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }

            Behavior on border.color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }

            Text {
              anchors.centerIn: parent
              text: counterProcess.running ? qsTr("Stop") : qsTr("Run Script")
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              font.bold: true
              color: counterProcess.running ? Theme.bgColor : Theme.textActiveColor
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor

              onClicked: {
                if (counterProcess.running) {
                  counterProcess.running = false;
                } else {
                  linesModel.clear();
                  panel.userScrolledUp = false;
                  counterProcess.running = true;
                }
              }
            }
          }
        }
      }
    }
  }
}
