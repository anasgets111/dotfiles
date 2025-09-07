import QtQuick

Row {
  id: rightSide

  spacing: 8

  Volume {
    anchors.verticalCenter: parent.verticalCenter
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
