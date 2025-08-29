import QtQuick
import QtQuick.Layouts
import qs.Services.WM
import qs.Config

Item {
  id: keyboardLayoutIndicator

  // Use KeyboardLayoutService singleton for all state and events

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, label.implicitWidth + 12)
  visible: KeyboardLayoutService.hasMultipleLayouts

  Rectangle {
    anchors.fill: parent
    color: Theme.inactiveColor
    radius: Theme.itemRadius

    RowLayout {
      anchors.fill: parent

      Text {
        id: label

        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        color: Theme.textContrast(Theme.inactiveColor)
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        text: KeyboardLayoutService.layoutShort
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
