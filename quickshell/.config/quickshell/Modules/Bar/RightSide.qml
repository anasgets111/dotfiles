import QtQuick

Row {
  id: rightSide

  // Mirror LeftSide's contract so we can reuse the same signal
  // to control CenterSide visibility when Volume expands/collapses
  required property bool normalWorkspacesExpanded

  spacing: 8

  PrivacyIndicator {
    anchors.verticalCenter: parent.verticalCenter
  }

  Volume {
    id: volume

    anchors.verticalCenter: parent.verticalCenter

    onExpandedChanged: rightSide.normalWorkspacesExpanded = expanded
  }

  ScreenRecorder {
    anchors.verticalCenter: parent.verticalCenter
  }

  NetworkIndicator {
    anchors.verticalCenter: parent.verticalCenter
  }

  BluetoothIndicator {
    anchors.verticalCenter: parent.verticalCenter
  }

  SysTray {
    anchors.verticalCenter: parent.verticalCenter
  }

  DateTimeDisplay {
    anchors.verticalCenter: parent.verticalCenter
  }
}
