pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

IconButton {
  property color tint: Theme.textActiveColor

  colorBg: "transparent"
  colorBgHover: Theme.withOpacity(tint, Theme.opacitySubtle)
  colorFg: Theme.withOpacity(tint, Theme.opacityDisabled)
  colorFgHover: tint
  shape: "rounded"
  showBorder: false
  size: "sm"
}
