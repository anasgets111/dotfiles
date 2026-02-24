import QtQuick
import qs.Config

Text {
  id: root

  readonly property color _computedColor: {
    if (accent)
      return Theme.activeColor;
    if (muted)
      return Theme.textInactiveColor;
    return Theme.textActiveColor;
  }
  readonly property int _computedSize: sizeMultiplier !== 1.0 ? Math.round(Theme.fontSize * sizeMultiplier) : Theme.fontSizeFor(size)
  readonly property int _computedWeight: {
    if (bold)
      return Font.Bold;
    return ({
        "light": Font.Light,
        "normal": Font.Normal,
        "medium": Font.Medium,
        "semibold": Font.DemiBold,
        "bold": Font.Bold
      })[weight] ?? Font.Normal;
  }

  property bool accent: false
  property bool bold: false
  property bool muted: false
  property string size: "md"
  property real sizeMultiplier: 1.0
  property bool useActiveColor: true
  property string weight: "normal"

  color: _computedColor
  elide: Text.ElideRight
  font.family: Theme.fontFamily
  font.pixelSize: _computedSize
  font.weight: _computedWeight
  verticalAlignment: Text.AlignVCenter

  onUseActiveColorChanged: if (!useActiveColor) muted = true
}
