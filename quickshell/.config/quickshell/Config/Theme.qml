pragma Singleton
import QtQuick
import Quickshell
import qs.Services.WM as WM

Singleton {
  id: theme

  readonly property real _devicePixelRatio: _mss
  // Diagonal in physical pixels (approx): sqrt(w^2 + h^2) * DPR
  readonly property real _diagonalPixels: Math.sqrt(_screenWidthPx * _screenWidthPx + _screenHeightPx * _screenHeightPx) * _devicePixelRatio

  // --- Responsive scaling prototype ---
  // We derive a baseScale from the active main monitor via MonitorService.
  // This is an initial test implementation: keep legacy fixed constants for now.
  // Formula: start from a resolution category factor, multiply by monitor scale (devicePixelRatio) moderation,
  // then clamp. Later we can migrate size tokens to use this.
  // Access via WM.MonitorService singleton
  readonly property var _mainScreen: (WM.MonitorService && WM.MonitorService.activeMainScreen) ? WM.MonitorService.activeMainScreen : null
  readonly property int _msh: _mainScreen ? _mainScreen.height : 1080
  readonly property real _mss: _mainScreen ? (_mainScreen.devicePixelRatio || _mainScreen.scale || 1) : 1
  readonly property int _msw: _mainScreen ? _mainScreen.width : 1920
  readonly property real _screenHeightPx: _msh
  // Compute a diagonal-based scale using pixel diagonal and device pixel ratio (DPR).
  // This produces a smooth, monotonic scale so smaller physical/low-res screens get
  // a smaller UI and larger/high-DPI screens scale up. We dampen DPR so HiDPI
  // doesn't double-inflate sizes.
  readonly property real _screenWidthPx: _msw
  readonly property color activeColor: "#CBA6F7"

  // Active/accent color variants (using withOpacity helper)
  readonly property color activeFull: withOpacity(activeColor, opacityFull)
  readonly property color activeLight: withOpacity(activeColor, opacityLight)
  readonly property color activeMedium: withOpacity(activeColor, opacityMedium)
  readonly property color activeSubtle: withOpacity(activeColor, opacitySubtle)
  readonly property int animationDuration: 147

  // ═══════════════════════════════════════════════════════════════════════════
  // ANIMATION TOKENS - Centralized easing and timing
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property int animationFast: 100
  // animationDuration (147ms) already exists as the standard
  readonly property int animationSlow: 250
  readonly property int animationVerySlow: 400
  // New: base widths for widgets that were previously hardcoded
  readonly property int baseBatteryPillWidth: 80
  // Base (unscaled) token values — used to compute scaled tokens below.
  readonly property int baseFontSize: 16
  readonly property int baseIconSize: 24
  readonly property int baseItemHeight: 34
  readonly property int baseItemRadius: 18
  readonly property int baseItemWidth: 34
  readonly property int basePanelHeight: 42
  // Map diagonalPixels to a scale value using linear mapping + clamps.
  // Tunable breakpoints: small laptops -> ~0.86, common 1080/1440 monitors -> ~0.95..1.12, 4K -> ~1.28
  readonly property real baseScale: {
    const diag = _diagonalPixels;
    // Target calibration points (approx):
    // - 1920x1080 -> diagonal ~2203 px -> prefer scale ~= 0.90
    // - 2560x1440 -> diagonal ~2938 px -> prefer scale ~= 1.00
    const diag1080 = 2203;
    const diag1440 = 2938;
    const scaleAt1080 = 0.9;
    const scaleAt1440 = 1;
    // Linear mapping coefficients: scale = a * diag + b
    const a = (scaleAt1440 - scaleAt1080) / (diag1440 - diag1080);
    const b = scaleAt1080 - (a * diag1080);
    let mappedScale = a * diag + b;
    // Damp additional DPR influence so very high DPRs don't over-scale
    const dampenedDprFactor = 1 + (_devicePixelRatio - 1) * 0.25;
    const combined = mappedScale * dampenedDprFactor;
    // Final clamp to reasonable bounds
    return Math.max(0.75, Math.min(1.4, combined));
  }
  readonly property int baseVolumeExpandedWidth: 220
  // New: centralized widths
  readonly property int batteryPillWidth: Math.max(60, Math.round(baseBatteryPillWidth * baseScale))

  // Background color variants
  readonly property color bgCard: withOpacity(bgColor, opacitySolid)
  readonly property color bgColor: "#1E1E2E"
  readonly property color bgElevated: Qt.lighter(bgColor, 1.35)
  readonly property color bgElevatedAlt: Qt.lighter(bgColor, 1.25)
  readonly property color bgElevatedHover: Qt.lighter(bgColor, 1.47)
  readonly property color bgInput: withOpacity(bgColor, opacityStrong)
  readonly property color bgOverlay: Qt.rgba(0, 0, 0, 0.5)  // Modal/dialog overlays
  readonly property color bgSubtle: withOpacity(bgColor, opacitySubtle)

  // ═══════════════════════════════════════════════════════════════════════════
  // DERIVED COLORS - Pre-computed transparent variants (avoids Qt.rgba repetition)
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property color borderColor: "#313244"

  // Border variants (using withOpacity for consistency)
  readonly property color borderLight: withOpacity(borderColor, opacityMedium)
  readonly property color borderMedium: withOpacity(borderColor, opacityMedium + 0.05)  // 0.4
  readonly property color borderStrong: withOpacity(borderColor, opacityDisabled)       // 0.5
  readonly property color borderSubtle: withOpacity(borderColor, 0.22)
  readonly property int borderWidthMedium: 2
  readonly property int borderWidthThick: 3

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDER WIDTH TOKENS
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property int borderWidthThin: 1

  // Card-specific padding (commonly used in panels)
  readonly property int cardPadding: Math.round(10 * baseScale)
  readonly property int controlHeightLg: Math.max(34, Math.round(42 * baseScale))  // 42px - large
  readonly property int controlHeightMd: Math.max(28, Math.round(34 * baseScale))  // 34px - default (matches itemHeight)
  readonly property int controlHeightSm: Math.max(24, Math.round(28 * baseScale))  // 28px - small
  readonly property int controlHeightXl: Math.max(42, Math.round(52 * baseScale))  // 52px - extra large

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPONENT SIZE PRESETS - For buttons, inputs, toggles, etc.
  // Usage: OButton { size: "sm" } or explicit height: Theme.controlHeightLg
  // ═══════════════════════════════════════════════════════════════════════════
  // Heights for interactive controls (buttons, inputs, toggles)
  readonly property int controlHeightXs: Math.max(20, Math.round(24 * baseScale))  // 24px - compact/inline
  readonly property int controlWidthLg: Math.max(40, Math.round(48 * baseScale))
  readonly property int controlWidthMd: Math.max(28, Math.round(34 * baseScale))   // matches itemWidth
  readonly property int controlWidthSm: Math.max(24, Math.round(32 * baseScale))
  readonly property int controlWidthXl: Math.max(52, Math.round(64 * baseScale))

  // Widths (minimum widths for controls)
  readonly property int controlWidthXs: Math.max(20, Math.round(24 * baseScale))
  readonly property color critical: "#f38ba8"
  readonly property int dialogPadding: Math.round(20 * baseScale)
  readonly property color disabledColor: "#232634"
  readonly property string fontFamily: "CaskaydiaCove Nerd Font Propo"
  readonly property int fontHero: Math.max(32, Math.round(48 * baseScale)) // 48px @ 1x - hero/display text

  readonly property int fontLg: Math.max(14, Math.round(16 * baseScale))   // 16px @ 1x - emphasis, subheadings (same as legacy fontSize)
  readonly property int fontMd: Math.max(12, Math.round(14 * baseScale))   // 14px @ 1x - body text (default)
  // Public tokens (scaled automatically). Widgets can keep using Theme.fontSize etc.
  readonly property int fontSize: Math.max(10, Math.round(baseFontSize * baseScale))
  readonly property int fontSm: Math.max(10, Math.round(12 * baseScale))   // 12px @ 1x - secondary text, captions
  readonly property int fontWeightBold: Font.Bold         // 700

  // Font weights as constants
  readonly property int fontWeightLight: Font.Light       // 300
  readonly property int fontWeightMedium: Font.Medium     // 500
  readonly property int fontWeightNormal: Font.Normal     // 400
  readonly property int fontWeightSemiBold: Font.DemiBold // 600
  readonly property int fontXl: Math.max(16, Math.round(20 * baseScale))   // 20px @ 1x - headings

  // ═══════════════════════════════════════════════════════════════════════════
  // TYPOGRAPHY SCALE - Semantic font sizes (all auto-scaled)
  // Usage: OText { size: "lg" } or font.pixelSize: Theme.fontLg
  // ═══════════════════════════════════════════════════════════════════════════
  // Size scale (scaled automatically via baseScale)
  readonly property int fontXs: Math.max(8, Math.round(10 * baseScale))    // 10px @ 1x - tiny labels, badges
  readonly property int fontXxl: Math.max(20, Math.round(28 * baseScale))  // 28px @ 1x - large headings
  readonly property string formatDateTime: " dd dddd hh:mm AP"

  // ═══════════════════════════════════════════════════════════════════════════
  // ICON FONT - For components using icon fonts (like OSD)
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property string iconFontFamily: "JetBrainsMono Nerd Font Mono"
  readonly property int iconSize: Math.max(12, Math.round(baseIconSize * baseScale))
  readonly property int iconSizeLg: Math.max(18, Math.round(24 * baseScale))
  readonly property int iconSizeMd: Math.max(14, Math.round(18 * baseScale))
  readonly property int iconSizeSm: Math.max(12, Math.round(14 * baseScale))
  readonly property int iconSizeXl: Math.max(24, Math.round(32 * baseScale))

  // Icon sizes within controls (auto-scaled)
  readonly property int iconSizeXs: Math.max(10, Math.round(12 * baseScale))
  readonly property color inactiveColor: "#494D64"
  readonly property int itemHeight: Math.max(20, Math.round(baseItemHeight * baseScale))
  readonly property int itemRadius: Math.max(6, Math.round(baseItemRadius * baseScale))
  readonly property int itemWidth: Math.max(20, Math.round(baseItemWidth * baseScale))
  readonly property color onHoverColor: "#A28DCD"

  // ═══════════════════════════════════════════════════════════════════════════
  // OPACITY PRESETS - Commonly used alpha values
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property real opacityDisabled: 0.5
  readonly property real opacityFull: 0.95        // Near-solid elements

  readonly property real opacityLight: 0.25       // Light overlays
  readonly property real opacityMedium: 0.35      // Borders, dividers
  readonly property real opacitySolid: 0.6        // Card backgrounds
  readonly property real opacityStrong: 0.8       // Input backgrounds
  readonly property real opacitySubtle: 0.15      // Subtle highlights, hover states
  readonly property int panelHeight: Math.max(28, Math.round(basePanelHeight * baseScale))
  readonly property int panelMargin: spacingMd
  readonly property int panelRadius: radiusMd
  readonly property color panelWindowColor: "transparent"
  readonly property int popupOffset: spacingMd
  readonly property color powerSaveColor: "#A6E3A1"
  readonly property int radiusFull: 9999  // Pill shape

  readonly property int radiusLg: Math.max(12, Math.round(18 * baseScale)) // 18px - large cards (matches itemRadius)
  readonly property int radiusMd: Math.max(8, Math.round(12 * baseScale))  // 12px - cards, panels

  // Radius presets for controls
  readonly property int radiusNone: 0
  readonly property int radiusSm: Math.max(4, Math.round(6 * baseScale))   // 6px - small buttons, tags
  readonly property int radiusXl: Math.max(20, Math.round(40 * baseScale)) // 40px - OSD, pills
  readonly property int radiusXs: Math.max(2, Math.round(3 * baseScale))   // 3px - tiny elements, checkmarks

  // UI element sizes
  readonly property int scrollBarWidth: spacingSm  // Default scrollbar width (8px scaled)

  readonly property int shadowBlurLg: 32
  readonly property int shadowBlurMd: 20
  readonly property int shadowBlurSm: 8

  // ═══════════════════════════════════════════════════════════════════════════
  // SHADOW TOKENS - Consistent shadow configurations
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.2)
  readonly property color shadowColorStrong: Qt.rgba(0, 0, 0, 0.55)
  readonly property int shadowOffsetY: 2
  readonly property int spacingLg: Math.round(16 * baseScale)  // Large: panel margins, major sections
  readonly property int spacingMd: Math.round(12 * baseScale)  // Medium: card padding, section gaps
  readonly property int spacingSm: Math.round(8 * baseScale)   // Small: button padding, list items
  readonly property int spacingXl: Math.round(24 * baseScale)  // Extra: dialog spacing, hero sections

  // ═══════════════════════════════════════════════════════════════════════════
  // SPACING TOKENS - Consistent spacing scale (scaled automatically)
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property int spacingXs: Math.round(4 * baseScale)   // Tight: icon gaps, inline elements
  readonly property color textActiveColor: "#CDD6F4"
  readonly property color textDisabled: withOpacity(textInactiveColor, opacityMedium)
  readonly property color textInactiveColor: "#A6ADC8"
  readonly property color textOnHoverColor: "#CBA6F7"
  readonly property int tooltipMaxSpace: 100
  readonly property int volumeExpandedWidth: Math.max(140, Math.round(baseVolumeExpandedWidth * baseScale))
  readonly property color warning: "#fab387"

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  function textContrast(bgColor) {
    function luminance(c) {
      return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    const l = luminance(bgColor);
    if (bgColor === theme.powerSaveColor)
      return "#CDD6F4";

    if (bgColor === theme.onHoverColor)
      return "#FFFFFF";

    return l > 0.6 ? "#4C4F69" : "#CDD6F4";
  }

  // Create a color with custom opacity from any base color
  function withOpacity(color, opacity) {
    return Qt.rgba(color.r, color.g, color.b, opacity);
  }
}
