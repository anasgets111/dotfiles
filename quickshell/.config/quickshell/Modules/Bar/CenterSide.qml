pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Modules.Bar.Indicators

Row {
  id: centerSide

  required property bool normalWorkspacesExpanded

  spacing: Theme.spacingSm

  ActiveWindow {
    id: activeWindowTitle

    anchors.verticalCenter: parent.verticalCenter
  }
}
