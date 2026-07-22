pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

Rectangle {
  id: root

  property color badgeColor: Theme.glassControlColor
  property string text: ""

  border.color: Theme.glassBorderColor
  border.width: Theme.borderWidthThin
  color: root.badgeColor
  implicitHeight: label.implicitHeight + 4
  implicitWidth: label.implicitWidth + 8
  radius: height / 2
  visible: root.text !== ""

  OText {
    id: label

    anchors.centerIn: parent
    bold: true
    color: Theme.textContrast(root.badgeColor)
    size: "xs"
    text: root.text
  }
}
