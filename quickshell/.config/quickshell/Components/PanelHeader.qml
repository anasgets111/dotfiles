pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config

RowLayout {
  id: root

  property color accent: Theme.activeColor
  property string icon: ""
  property string subtitle: ""
  property string title: ""
  default property alias trailing: trailingSlot.data

  Layout.fillWidth: true
  spacing: Theme.spacingSm

  Rectangle {
    Layout.preferredHeight: Theme.controlHeightLg
    Layout.preferredWidth: Theme.controlHeightLg
    color: Theme.withOpacity(root.accent, Theme.opacitySubtle)
    radius: Theme.radiusMd

    Theme.ColorTransition on color {
    }

    OText {
      anchors.centerIn: parent
      color: root.accent
      font.family: Theme.iconFontFamily
      font.pixelSize: Theme.iconSizeLg
      text: root.icon

      Theme.ColorTransition on color {
      }
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0

    OText {
      Layout.fillWidth: true
      bold: true
      color: Theme.textActiveColor
      size: "lg"
      text: root.title
    }
    OText {
      Layout.fillWidth: true
      color: Theme.textInactiveColor
      size: "xs"
      text: root.subtitle
      visible: text !== ""
    }
  }
  RowLayout {
    id: trailingSlot

    Layout.alignment: Qt.AlignVCenter
    spacing: Theme.spacingXs
  }
}
