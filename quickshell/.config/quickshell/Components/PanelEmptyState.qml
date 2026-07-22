import QtQuick
import QtQuick.Layouts
import qs.Config

Item {
  id: root

  property string icon: ""
  property real iconOpacity: Theme.opacityMedium
  property string text: ""

  ColumnLayout {
    anchors.centerIn: parent
    spacing: Theme.spacingSm

    Text {
      Layout.alignment: Qt.AlignHCenter
      color: Theme.textInactiveColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize * 2
      opacity: root.iconOpacity
      text: root.icon
    }
    OText {
      Layout.alignment: Qt.AlignHCenter
      color: Theme.textInactiveColor
      text: root.text
    }
  }
}
