import QtQuick
import qs.Config
import qs.Modules.Bar.Indicators

Row {
  id: rightSide

  required property bool normalWorkspacesExpanded

  spacing: Theme.spacingSm

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
