import QtQuick
import QtQuick.Layouts
import qs.Config

Rectangle {
  id: root

  readonly property int _fontSize: Theme.fontSizeFor(size)
  readonly property int _height: Theme.controlHeightFor(size)
  readonly property int _iconSize: Theme.iconSizeFor(size)
  readonly property int _padding: Theme.spacingFor(size)
  readonly property color _variantBgColor: {
    switch (variant) {
    case "primary":
      return Theme.activeColor;
    case "secondary":
      return Theme.glassControlColor;
    case "ghost":
      return "transparent";
    default:
      return Theme.activeColor;
    }
  }
  property color bgColor: _variantBgColor
  default property alias content: contentContainer.data
  readonly property color currentBackground: !isEnabled ? Theme.disabledColor : (hovered ? hoverColor : bgColor)
  property color hoverColor: variant === "secondary" ? Theme.glassControlHoverColor : Qt.lighter(bgColor, 1.2)
  property alias hovered: mouseArea.containsMouse
  property string icon: ""
  property bool isEnabled: true
  property string size: "md"
  property string text: ""
  property color textColor: Theme.textContrast(currentBackground)
  property string variant: "primary"

  signal clicked

  border.color: variant === "secondary" ? Theme.glassBorderColor : "transparent"
  border.width: Theme.borderWidthThin
  color: currentBackground
  implicitHeight: _height
  implicitWidth: simpleContent.visible ? simpleContent.implicitWidth + _padding * 2 : contentContainer.implicitWidth
  opacity: isEnabled ? 1 : Theme.opacityDisabled
  radius: Theme.radiusMd

  Behavior on color {
    ColorAnimation {
      duration: Theme.animationDuration
    }
  }

  RowLayout {
    id: simpleContent

    anchors.centerIn: parent
    spacing: Theme.spacingSm
    visible: root.text !== "" || root.icon !== ""

    OText {
      color: root.textColor
      font.pixelSize: root._iconSize
      text: root.icon
      visible: root.icon !== ""
    }
    OText {
      bold: true
      color: root.textColor
      font.pixelSize: root._fontSize
      text: root.text
      visible: root.text !== ""
    }
  }
  Item {
    id: contentContainer

    anchors.fill: parent
    visible: !simpleContent.visible
  }
  MouseArea {
    id: mouseArea

    anchors.fill: parent
    cursorShape: root.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: root.isEnabled
    hoverEnabled: true

    onClicked: root.clicked()
  }
}
