pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

Item {
  id: root

  required property string section
  property string sectionLabel: root.section

  implicitHeight: label.implicitHeight + Theme.spacingXs

  OText {
    id: label

    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.leftMargin: Theme.spacingSm
    bold: true
    color: Theme.textInactiveColor
    opacity: Theme.opacityMuted
    size: "xs"
    text: root.sectionLabel
  }
}
