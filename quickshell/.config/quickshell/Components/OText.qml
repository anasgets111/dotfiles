import QtQuick
import qs.Config

/**
 * OText - Obelisk themed text component
 *
 * A Text component with Theme styling applied by default.
 * All properties can be overridden as needed.
 */
Text {
  id: root

  property real sizeMultiplier: 1
  property bool useActiveColor: true

  color: useActiveColor ? Theme.textActiveColor : Theme.textInactiveColor
  elide: Text.ElideRight
  font.family: Theme.fontFamily
  font.pixelSize: Theme.fontSize * sizeMultiplier
  verticalAlignment: Text.AlignVCenter
}
