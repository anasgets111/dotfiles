import QtQuick
import QtQuick.Controls
import Quickshell.Io

Item {
  id: root

  property bool hovered: false
  property bool isRecording: false
  property string statusText: ""

  height: Theme.itemHeight
  visible: statusText !== ""
  width: Theme.itemWidth

  Timer {
    id: pollTimer

    interval: 2000
    repeat: true
    running: true

    onTriggered: {
      statusProcess.running = true;
    }
  }
  Process {
    id: statusProcess

    command: ["/home/anas/.local/bin/RecordingStatus.sh"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var json = JSON.parse(this.text);
          root.statusText = json.text || "";
          root.isRecording = json.isRecording || false;
        } catch (e) {
          root.statusText = "";
          root.isRecording = false;
        }
      }
    }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: {
      var toggleProcess = Qt.createQmlObject('import Quickshell.Io 1.0; Process {}', root);
      toggleProcess.command = ["sh", "/home/anas/.local/bin/ScreenRecording.sh"];
      toggleProcess.running = true;
    }
    onEntered: root.hovered = true
    onExited: root.hovered = false
  }
  Rectangle {
    anchors.fill: parent
    border.color: Theme.borderColor
    border.width: 1
    color: root.isRecording ? Theme.activeColor : (root.hovered ? Theme.onHoverColor : Theme.inactiveColor)
    radius: Theme.itemRadius

    Text {
      anchors.centerIn: parent
      color: Theme.textContrast(root.isRecording ? Theme.activeColor : (root.hovered ? Theme.onHoverColor : Theme.inactiveColor))
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      text: root.statusText
    }
  }
}
