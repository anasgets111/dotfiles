pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

Row {
  id: centerSide

  required property bool normalWorkspacesExpanded

  spacing: Theme.spacingSm

  ActiveWindow {
    id: activeWindowTitle

    anchors.verticalCenter: parent.verticalCenter
  }
}
