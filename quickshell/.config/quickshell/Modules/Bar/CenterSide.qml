pragma ComponentBehavior: Bound

import QtQuick

Row {
  id: centerSide

  required property bool normalWorkspacesExpanded

  spacing: 8

  // Active window title display
  ActiveWindow {
    id: activeWindowTitle

    anchors.verticalCenter: parent.verticalCenter
    visible: true
  }
}
