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
    bottomPadding: 8
    leftPadding: 12
    text: root.displayText
    topPadding: 8
  }
  popup: Popup {
    implicitHeight: contentItem.implicitHeight + 20
    padding: 10
    width: root.width
    y: root.height + 4

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
