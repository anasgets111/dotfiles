import QtQuick
import qs.Components
import qs.Config
import qs.Services.WM

Item {
  id: keyboardLayoutIndicator

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)
  visible: KeyboardLayoutService.hasMultipleLayouts

  IconButton {
    id: iconButton

    anchors.fill: parent
    icon: KeyboardLayoutService.layoutShort
    tooltipText: KeyboardLayoutService.currentLayout

    onClicked: KeyboardLayoutService.nextLayout()
  }
}
