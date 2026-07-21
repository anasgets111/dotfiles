pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

IconButton {
  id: btn

  property color tint: Theme.textActiveColor

  colorBg: "transparent"
  colorBgHover: Theme.withOpacity(btn.tint, Theme.opacitySubtle)
  colorFg: Theme.withOpacity(btn.tint, Theme.opacityDisabled)
  colorFgHover: btn.tint
  shape: "rounded"
  showBorder: false
  size: "sm"
}
