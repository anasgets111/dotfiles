import QtQuick
import QtQuick.Layouts
import qs.Config

Item {
  id: root

  property string icon: ""
  property string subtext: ""
  property string text: ""

  ColumnLayout {
    anchors.centerIn: parent
    spacing: Theme.spacingSm

    Text {
      Layout.alignment: Qt.AlignHCenter
      color: Theme.textInactiveColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize * 2
      opacity: Theme.opacityMedium
      text: root.icon
    }
    OText {
      Layout.alignment: Qt.AlignHCenter
      color: Theme.textInactiveColor
      text: root.text
    }
    OText {
      Layout.alignment: Qt.AlignHCenter
      color: Theme.textInactiveColor
      horizontalAlignment: Text.AlignHCenter
      opacity: Theme.opacityMuted
      size: "sm"
      text: root.subtext
      visible: root.subtext !== ""
    }
  }
}
