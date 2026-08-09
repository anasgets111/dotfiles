pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config

RowLayout {
  id: root

  property color accent: Theme.activeColor
  property bool compact: false
  property string icon: ""
  property string subtitle: ""
  property string subtitleSize: "xs"
  property string title: ""
  property bool titleBold: true
  property string titleSize: "lg"
  default property alias trailing: trailingSlot.data

  Layout.fillWidth: true
  spacing: Theme.spacingSm

  Rectangle {
    Layout.preferredHeight: root.compact ? Theme.controlHeightMd : Theme.controlHeightLg
    Layout.preferredWidth: root.compact ? Theme.controlHeightMd : Theme.controlHeightLg
    color: root.compact ? "transparent" : Theme.withOpacity(root.accent, Theme.opacitySubtle)
    radius: Theme.radiusMd

    Theme.ColorTransition on color {
    }

    OText {
      anchors.centerIn: parent
      color: root.accent
      font.family: Theme.iconFontFamily
      font.pixelSize: root.compact ? Theme.fontMd : Theme.iconSizeLg
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
      bold: root.titleBold
      color: Theme.textActiveColor
      size: root.titleSize
      text: root.title
    }
    OText {
      Layout.fillWidth: true
      color: Theme.textInactiveColor
      elide: Text.ElideNone
      size: root.subtitleSize
      text: root.subtitle
      visible: text !== ""
      wrapMode: Text.Wrap
    }
  }
  RowLayout {
    id: trailingSlot

    Layout.alignment: Qt.AlignVCenter
    spacing: Theme.spacingXs
  }
}
