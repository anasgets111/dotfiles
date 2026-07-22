import QtQuick
import QtQuick.Controls
import qs.Config

ComboBox {
  id: root

  opacity: enabled ? 1 : Theme.opacityDisabled

  background: Rectangle {
    border.color: root.activeFocus ? Theme.activeColor : Theme.glassBorderColor
    border.width: Theme.borderWidthThin
    color: Theme.glassInputColor
    radius: Theme.itemRadius
  }
  contentItem: OText {
    bottomPadding: Theme.spacingSm
    leftPadding: Theme.spacingMd
    text: root.displayText
    topPadding: Theme.spacingSm
  }
  popup: Popup {
    implicitHeight: contentItem.implicitHeight + Theme.dialogPadding
    padding: Theme.spacingMd
    width: root.width
    y: root.height + Theme.spacingXs

    background: Rectangle {
      border.color: Theme.glassBorderColor
      border.width: Theme.borderWidthThin
      color: Theme.glassContentColor
      radius: Theme.itemRadius
    }
    contentItem: ListView {
      clip: true
      implicitHeight: contentHeight
      model: root.delegateModel

      ScrollIndicator.vertical: ScrollIndicator {
      }
    }
  }
}
