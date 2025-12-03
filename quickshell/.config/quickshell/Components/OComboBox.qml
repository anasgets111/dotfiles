import QtQuick
import QtQuick.Controls
import qs.Config

ComboBox {
  id: root

  background: Rectangle {
    border.color: Theme.borderColor
    border.width: 1
    color: Theme.bgColor
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
      border.color: Theme.borderColor
      border.width: 1
      color: Theme.bgColor
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
