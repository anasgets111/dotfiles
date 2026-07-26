pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

Item {
  property bool flatContainer: false
  property bool isOpen: false
  // Vertical room the host can actually give this panel. Panels that scroll internally size against
  // this instead of guessing; 0 means the host has not published it yet.
  property real maxAvailableHeight: 0
  property bool needsKeyboardFocus: false
  property var panelData: null
  property real preferredHeight: 1
  property real preferredWidth: Theme.panelDefaultWidth

  signal closeRequested
}
