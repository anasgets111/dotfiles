import QtQuick
import qs.Services.WM
import qs.Config
import qs.Components

Item {
  id: keyboardLayoutIndicator

  // Use KeyboardLayoutService singleton for all state and events

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)
  visible: KeyboardLayoutService.hasMultipleLayouts

  IconButton {
    id: iconButton
    enabled: false
    icon: KeyboardLayoutService.layoutShort
    tooltipText: KeyboardLayoutService.currentLayout
  }
}
