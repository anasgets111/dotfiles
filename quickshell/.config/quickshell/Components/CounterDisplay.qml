pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

import qs.Config

PanelWindow {
  id: counterWindow

  anchors {
    top: true
    right: true
  }

  margins {
    top: Theme.baseScale * 10
    right: Theme.baseScale * 150
  }

  width: Theme.baseScale * 300
  height: Theme.baseScale * 400

  color: "transparent"

  ListModel {
    id: linesModel
  }

  property bool userScrolledUp: false

  Process {
    id: counterProcess

    command: ["/bin/bash", Qt.resolvedUrl("../scripts/counter.sh").toString().replace("file://", "")]
    running: false  // Don't auto-start

    stdout: SplitParser {
      onRead: data => {
        const line = data.trim();
        if (line !== "") {
          linesModel.append({
            lineText: line
          });
          // Only auto-scroll if user hasn't scrolled up
          if (!counterWindow.userScrolledUp) {
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

  Rectangle {
    anchors.fill: parent
    color: Theme.bgColor
    radius: Theme.itemRadius
    border.width: 1
    border.color: Theme.borderColor

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

        // Track if we're at the bottom
        onContentYChanged: {
          const atBottom = listView.atYEnd || (listView.contentHeight - listView.contentY - listView.height) < 10;
          counterWindow.userScrolledUp = !atBottom;
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
              // Clear previous output
              linesModel.clear();
              counterWindow.userScrolledUp = false;
              counterProcess.running = true;
            }
          }
        }
      }
    }
  }
}
