pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

Item {
  property bool flatContainer: false
  property bool isOpen: false
  // Vertical room the host can actually give this panel. Panels that scroll internally size against
  // this instead of guessing; unbounded until the host publishes a real ceiling.
  property real maxAvailableHeight: Number.POSITIVE_INFINITY
  property bool needsKeyboardFocus: false
  property var panelData: null
  property real preferredHeight: 1
  property real preferredWidth: Theme.panelDefaultWidth

  signal closeRequested
}
