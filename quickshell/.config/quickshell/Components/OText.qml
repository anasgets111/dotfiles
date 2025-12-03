import QtQuick
import qs.Config

/**
 * OText - Obelisk themed text component
 *
 * A Text component with Theme styling applied by default.
 * All font properties come from Theme and can be overridden.
 *
 * Size presets: "xs", "sm", "md" (default), "lg", "xl", "xxl", "hero"
 * Weight presets: "light", "normal" (default), "medium", "semibold", "bold"
 *
 * Examples:
 *   OText { text: "Hello" }                           // Default md size, normal weight
 *   OText { text: "Title"; size: "xl"; bold: true }
 *   OText { text: "Caption"; size: "sm"; muted: true }
 *   OText { text: "Custom"; font.pixelSize: 20 }     // Direct override still works
 */
Text {
  id: root

  // Internal computed color
  readonly property color _computedColor: {
    if (accent)
      return Theme.activeColor;
    if (muted)
      return Theme.textInactiveColor;
    return Theme.textActiveColor;
  }

  // Internal computed font size using Theme helper function
  readonly property int _computedSize: {
    // If sizeMultiplier is not default, use legacy behavior
    if (sizeMultiplier !== 1.0)
      return Math.round(Theme.fontSize * sizeMultiplier);
    return Theme.fontSizeFor(size);
  }

  // Internal computed font weight
  readonly property int _computedWeight: {
    if (bold)
      return Font.Bold;
    switch (weight) {
    case "light":
      return Font.Light;
    case "normal":
      return Font.Normal;
    case "medium":
      return Font.Medium;
    case "semibold":
      return Font.DemiBold;
    case "bold":
      return Font.Bold;
    default:
      return Font.Normal;
    }
  }
  property bool accent: false     // Use accent/active color

  // Convenience flags
  property bool bold: false       // Shorthand for weight: "bold"
  property bool muted: false      // Use inactive/secondary color

  // Size preset: "xs", "sm", "md", "lg", "xl", "xxl", "hero"
  property string size: "md"

  // Legacy support (deprecated - use size preset instead)
  property real sizeMultiplier: 1.0

  // Legacy property for backwards compatibility
  property bool useActiveColor: true

  // Weight preset: "light", "normal", "medium", "semibold", "bold"
  property string weight: "normal"

  color: _computedColor
  elide: Text.ElideRight
  font.family: Theme.fontFamily
  font.pixelSize: _computedSize
  font.weight: _computedWeight
  verticalAlignment: Text.AlignVCenter

  onUseActiveColorChanged: if (!useActiveColor)
    muted = true
}
