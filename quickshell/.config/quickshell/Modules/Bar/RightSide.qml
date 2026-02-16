import QtQuick
import qs.Config
import qs.Modules.Bar.Indicators

Row {
  id: rightSide

  required property bool normalWorkspacesExpanded
  required property string screenName

  spacing: Theme.spacingSm

  PrivacyIndicator {
    anchors.verticalCenter: parent.verticalCenter
  }

  Volume {
    id: volume

    anchors.verticalCenter: parent.verticalCenter
    screenName: rightSide.screenName

    onExpandedChanged: rightSide.normalWorkspacesExpanded = expanded
  }

  ScreenRecorder {
    anchors.verticalCenter: parent.verticalCenter
  }

  NetworkIndicator {
    anchors.verticalCenter: parent.verticalCenter
    screenName: rightSide.screenName
  }

  BluetoothIndicator {
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
