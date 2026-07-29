import QtQuick
import qs.Config
import qs.Modules.Bar.Indicators

Row {
  id: rightSide

  required property string screenName

  spacing: Theme.spacingSm

  PrivacyIndicator {
    anchors.verticalCenter: parent.verticalCenter
  }
  Volume {
    anchors.verticalCenter: parent.verticalCenter
    screenName: rightSide.screenName
  }
  ScreenRecorder {
    anchors.verticalCenter: parent.verticalCenter
    screenName: rightSide.screenName
  }
  NetworkIndicator {
    anchors.verticalCenter: parent.verticalCenter
    screenName: rightSide.screenName
  }
  BluetoothIndicator {
    anchors.verticalCenter: parent.verticalCenter
    screenName: rightSide.screenName
  }
  KDEConnectIndicator {
    anchors.verticalCenter: parent.verticalCenter
    screenName: rightSide.screenName
  }
  SysTray {
    anchors.verticalCenter: parent.verticalCenter
    screenName: rightSide.screenName
  }
  DateTimeDisplay {
    anchors.verticalCenter: parent.verticalCenter
    screenName: rightSide.screenName
  }
}
