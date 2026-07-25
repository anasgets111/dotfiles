pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config

Item {
  id: root

  required property string section
  property string sectionLabel: root.section
  default property alias trailing: trailingSlot.data

  implicitHeight: Math.max(label.implicitHeight, trailingSlot.implicitHeight) + Theme.spacingXs

  OText {
    id: label

    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.leftMargin: Theme.spacingSm
    bold: true
    color: Theme.textInactiveColor
    opacity: Theme.opacityMuted
    size: "xs"
    text: root.sectionLabel.toUpperCase()
  }
  RowLayout {
    id: trailingSlot

    anchors.right: parent.right
    anchors.verticalCenter: label.verticalCenter
    spacing: Theme.spacingXs
  }
}
