import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.Config

/**
 * OButton - Obelisk themed button component
 *
 * A clickable button with hover states, icons, and text.
 * Uses Theme for all styling with smooth transitions.
 *
 * Size presets: "xs", "sm", "md" (default), "lg", "xl"
 * Variant presets: "primary" (default), "secondary", "ghost"
 *
 * Examples:
 *   OButton { text: "Click" }                          // Default md primary
 *   OButton { text: "Small"; size: "sm" }
 *   OButton { icon: "󰅖"; size: "lg" }
 *   OButton { text: "Cancel"; variant: "secondary" }
 */
Rectangle {
  id: root

  readonly property int _fontSize: {
    switch (size) {
    case "xs":
      return Theme.fontXs;
    case "sm":
      return Theme.fontSm;
    case "md":
      return Theme.fontMd;
    case "lg":
      return Theme.fontLg;
    case "xl":
      return Theme.fontXl;
    default:
      return Theme.fontMd;
    }
  }

  // Internal: size-based dimensions
  readonly property int _height: {
    switch (size) {
    case "xs":
      return Theme.controlHeightXs;
    case "sm":
      return Theme.controlHeightSm;
    case "md":
      return Theme.controlHeightMd;
    case "lg":
      return Theme.controlHeightLg;
    case "xl":
      return Theme.controlHeightXl;
    default:
      return Theme.controlHeightMd;
    }
  }
  readonly property int _iconSize: {
    switch (size) {
    case "xs":
      return Theme.iconSizeXs;
    case "sm":
      return Theme.iconSizeSm;
    case "md":
      return Theme.iconSizeMd;
    case "lg":
      return Theme.iconSizeLg;
    case "xl":
      return Theme.iconSizeXl;
    default:
      return Theme.iconSizeMd;
    }
  }
  readonly property int _padding: {
    switch (size) {
    case "xs":
      return Theme.spacingXs;
    case "sm":
      return Theme.spacingSm;
    case "md":
      return Theme.spacingMd;
    case "lg":
      return Theme.spacingLg;
    case "xl":
      return Theme.spacingXl;
    default:
      return Theme.spacingMd;
    }
  }

  // Internal: variant-based default colors
  readonly property color _variantBgColor: {
    switch (variant) {
    case "primary":
      return Theme.activeColor;
    case "secondary":
      return Theme.inactiveColor;
    case "ghost":
      return "transparent";
    default:
      return Theme.activeColor;
    }
  }

  // Color overrides (use variant for defaults, or override directly)
  property color bgColor: _variantBgColor

  // Content container for custom children
  default property alias content: contentContainer.data

  // Computed properties
  readonly property color currentBackground: !isEnabled ? Theme.disabledColor : (hovered ? hoverColor : bgColor)
  property color hoverColor: Qt.lighter(bgColor, 1.2)
  property alias hovered: mouseArea.containsMouse

  // Content properties
  property string icon: ""

  // Behavior
  property bool isEnabled: true

  // Size preset: "xs", "sm", "md", "lg", "xl"
  property string size: "md"
  property string text: ""
  property color textColor: Theme.textContrast(currentBackground)

  // Variant preset: "primary", "secondary", "ghost"
  property string variant: "primary"

  signal clicked

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

  // Simple mode: text/icon layout
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

  // Custom content mode
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
