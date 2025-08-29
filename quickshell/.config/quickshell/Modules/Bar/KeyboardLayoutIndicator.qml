import QtQuick
import qs.Services.WM
import qs.Config
import qs.Widgets

Item {
  id: keyboardLayoutIndicator

  // Use KeyboardLayoutService singleton for all state and events

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)
  visible: KeyboardLayoutService.hasMultipleLayouts

  IconButton {
    id: iconButton

    disabled: true
    iconText: KeyboardLayoutService.layoutShort
  }
  Tooltip {
    hoverSource: iconButton.area
    target: iconButton
    text: KeyboardLayoutService.currentLayout
  }
}
