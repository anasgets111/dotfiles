pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

Item {
  property bool flatContainer: false
  property bool isOpen: false
  property var panelData: null
  property real preferredHeight: 1
  property real preferredWidth: Theme.panelDefaultWidth

  signal closeRequested
}
