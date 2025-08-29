import QtQuick
import qs.Config

Row {
  id: centerSide

  required property bool normalWorkspacesExpanded

  spacing: 8

  // Active window title display
  ActiveWindow {
    id: activeWindowTitle

    anchors.verticalCenter: parent.verticalCenter
    opacity: centerSide.normalWorkspacesExpanded ? 0 : 1
    visible: true

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.InOutQuad
      }
    }
  }
}
