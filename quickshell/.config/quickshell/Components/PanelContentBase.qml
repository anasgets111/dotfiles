pragma ComponentBehavior: Bound

import QtQuick

Item {
  property bool isOpen: false
  property bool needsKeyboardFocus: false
  property var panelData: null
  property real preferredHeight: 1
  property real preferredWidth: 350

  signal closeRequested
}
