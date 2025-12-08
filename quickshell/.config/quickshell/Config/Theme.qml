pragma Singleton
import QtQuick
import Quickshell
import qs.Config as Config
import qs.Services.WM as WM

Singleton {
  id: theme

  // --- Colors (Base) ---
  readonly property color activeColor: internal.c.activeColor ?? "#cba6f7"

  // --- Color Variants (Computed) ---
  readonly property color activeFull: internal.c.activeFull ?? withOpacity(activeColor, opacityFull)
  readonly property color activeLight: internal.c.activeLight ?? withOpacity(activeColor, opacityLight)
  readonly property color activeMedium: internal.c.activeMedium ?? withOpacity(activeColor, opacityMedium)
  readonly property color activeSubtle: internal.c.activeSubtle ?? withOpacity(activeColor, opacitySubtle)

  // --- Animation ---
  readonly property int animationDuration: 147
  readonly property int animationFast: 100
  readonly property int animationSlow: 250
  readonly property int animationVerySlow: 400
  readonly property int baseBatteryPillWidth: 80

  // --- Base Sizes (Unscaled) ---
  readonly property int baseFontSize: 16
  readonly property int baseIconSize: 24
  readonly property int baseItemHeight: 34
  readonly property int baseItemRadius: 18
  readonly property int baseItemWidth: 34
  readonly property int basePanelHeight: 42

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC PROPERTIES
  // ═══════════════════════════════════════════════════════════════════════════

  // --- Scaling ---
  readonly property real baseScale: internal.scaleFactor
  readonly property int baseVolumeExpandedWidth: 220

  // Widgets Specifics
  readonly property int batteryPillWidth: s(baseBatteryPillWidth, 60)
  readonly property color bgCard: internal.c.bgCard ?? withOpacity(bgColor, opacitySolid)
  readonly property color bgColor: internal.c.bgColor ?? "#1e1e2e"
  readonly property color bgElevated: internal.c.bgElevated ?? Qt.lighter(bgColor, 1.35)
  readonly property color bgElevatedAlt: internal.c.bgElevatedAlt ?? Qt.lighter(bgColor, 1.25)
  readonly property color bgElevatedHover: internal.c.bgElevatedHover ?? Qt.lighter(bgColor, 1.47)
  readonly property color bgInput: internal.c.bgInput ?? withOpacity(bgColor, opacityStrong)
  readonly property color bgOverlay: withOpacity(internal.c.bgOverlay ?? "#000000", 0.5)
  readonly property color bgSubtle: internal.c.bgSubtle ?? withOpacity(bgColor, opacitySubtle)
  readonly property color borderColor: internal.c.borderColor ?? "#313244"
  readonly property color borderLight: internal.c.borderLight ?? withOpacity(borderColor, opacityMedium)
  readonly property color borderMedium: internal.c.borderMedium ?? withOpacity(borderColor, opacityMedium + 0.05)
  readonly property color borderStrong: internal.c.borderStrong ?? withOpacity(borderColor, opacityDisabled)
  readonly property color borderSubtle: internal.c.borderSubtle ?? withOpacity(borderColor, 0.22)
  readonly property int borderWidthMedium: 2

  // Borders & Shadows
  readonly property int borderWidthThick: 3
  readonly property int borderWidthThin: 1
  readonly property int cardPadding: s(10)
  readonly property int controlHeightLg: s(basePanelHeight, 34)
  readonly property int controlHeightMd: s(baseItemHeight, 28)
  readonly property int controlHeightSm: s(28, 24)

  // Controls (Heights)
  readonly property int controlHeightXl: s(52, 42)
  readonly property int controlHeightXs: s(24, 20)
  readonly property int controlWidthLg: s(48, 40)
  readonly property int controlWidthMd: s(baseItemWidth, 28)
  readonly property int controlWidthSm: s(32, 24)

  // Controls (Widths)
  readonly property int controlWidthXl: s(64, 52)
  readonly property int controlWidthXs: s(24, 20)
  readonly property color critical: internal.c.critical ?? "#f38ba8"
  readonly property int dialogPadding: s(20)

  // Dialog Width Ratio
  readonly property real dialogWidthRatio: internal.isUltrawide ? 0.45 : 0.6
  readonly property color disabledColor: internal.c.disabledColor ?? "#232634"

  // Fonts
  readonly property string fontFamily: "CaskaydiaCove Nerd Font Propo"
  readonly property int fontHero: s(48, 32)
  readonly property int fontLg: s(16, 14)
  readonly property int fontMd: s(14, 12)
  readonly property int fontSize: s(baseFontSize, 10) // Base/Md
  readonly property int fontSm: s(12, 10)
  readonly property int fontWeightBold: Font.Bold
  readonly property int fontWeightLight: Font.Light
  readonly property int fontWeightMedium: Font.Medium
  readonly property int fontWeightNormal: Font.Normal
  readonly property int fontWeightSemiBold: Font.DemiBold
  readonly property int fontXl: s(20, 16)
  readonly property int fontXs: s(10, 8)
  readonly property int fontXxl: s(28, 20)
  readonly property string formatDateTime: " dd dddd hh:mm AP"
  readonly property string iconFontFamily: "JetBrainsMono Nerd Font Mono"
  readonly property int iconSize: s(baseIconSize, 12) // Base/Md
  readonly property int iconSizeLg: s(24, 18)
  readonly property int iconSizeMd: s(18, 14)
  readonly property int iconSizeSm: s(14, 12)

  // Icons
  readonly property int iconSizeXl: s(32, 24)
  readonly property int iconSizeXs: s(12, 10)
  readonly property color inactiveColor: internal.c.inactiveColor ?? "#494d64"

  // --- Scaled Dimensions (Using helper s()) ---
  // General
  readonly property int itemHeight: s(baseItemHeight, 20)
  readonly property int itemRadius: s(baseItemRadius, 6)
  readonly property int itemWidth: s(baseItemWidth, 20)
  readonly property int launcherCellSize: s(150)
  readonly property int launcherIconSize: s(72)
  readonly property int launcherWindowHeight: s(471)

  // Launcher
  readonly property int launcherWindowWidth: s(741)

  // Lock Screen
  readonly property int lockCardContentWidth: Math.round(400 * baseScale * lockScale)
  readonly property int lockCardMaxWidth: Math.round(500 * baseScale * lockScale)
  readonly property real lockScale: internal.lockScale // Exposed for lockCard logic

  readonly property int notificationAppIconSize: s(40)
  readonly property int notificationCardWidth: s(380)
  readonly property int notificationInlineImageSize: s(24)
  readonly property color onHoverColor: internal.c.onHoverColor ?? "#a28dcd"
  readonly property real opacityDisabled: 0.5

  // --- Opacity ---
  readonly property real opacityFull: 0.95
  readonly property real opacityLight: 0.25
  readonly property real opacityMedium: 0.35
  readonly property real opacitySolid: 0.6
  readonly property real opacityStrong: 0.8
  readonly property real opacitySubtle: 0.15

  // OSD
  readonly property int osdAnimationOffset: s(60)
  readonly property int osdCardHeight: s(80)
  readonly property int osdSliderTrackHeight: s(12)
  readonly property int osdSliderWidth: s(300)
  readonly property int osdToggleIconContainerSize: s(48)
  readonly property int osdToggleMinWidth: s(220)
  readonly property int panelHeight: s(basePanelHeight, 28)
  readonly property int panelMargin: spacingMd
  readonly property int panelRadius: radiusMd
  readonly property color panelWindowColor: internal.c.panelWindowColor ?? "transparent"
  readonly property int popupOffset: spacingMd
  readonly property color powerSaveColor: internal.c.powerSaveColor ?? "#a6e3a1"
  readonly property int radiusFull: 9999
  readonly property int radiusLg: s(baseItemRadius, 12)
  readonly property int radiusMd: s(12, 8)
  readonly property int radiusNone: 0
  readonly property int radiusSm: s(6, 4)
  readonly property int radiusXl: s(40, 20)
  readonly property int radiusXs: s(3, 2)

  // Scale Variants (Multipliers)
  readonly property real scaleExtraLarge: 1.5
  readonly property real scaleLarge: 1.2
  readonly property real scaleMedium: 0.9
  readonly property real scaleMediumSmall: 0.8
  readonly property real scaleNormal: 1.0
  readonly property real scaleSmall: 0.7

  // Scrollbar
  readonly property int scrollBarWidth: spacingSm
  readonly property int shadowBlurLg: 32
  readonly property int shadowBlurMd: 20
  readonly property int shadowBlurSm: 8
  readonly property color shadowColor: withOpacity(internal.c.shadowColor ?? "#000000", 0.2)
  readonly property color shadowColorStrong: withOpacity(internal.c.shadowColorStrong ?? "#000000", 0.55)
  readonly property int shadowOffsetY: 2
  readonly property int spacingLg: s(16)
  readonly property int spacingMd: s(12)
  readonly property int spacingSm: s(8)

  // Spacing & Radius
  readonly property int spacingXl: s(24)
  readonly property int spacingXs: s(4)
  readonly property color textActiveColor: internal.c.textActiveColor ?? "#cdd6f4"
  readonly property color textDisabled: internal.c.textDisabled ?? withOpacity(textInactiveColor, opacityMedium)
  readonly property color textInactiveColor: internal.c.textInactiveColor ?? "#a6adc8"
  readonly property color textOnHoverColor: internal.c.textOnHoverColor ?? "#cba6f7"
  readonly property int tooltipMaxSpace: 100
  readonly property int volumeExpandedWidth: s(baseVolumeExpandedWidth, 140)
  readonly property color warning: internal.c.warning ?? "#fab387"

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  function controlHeightFor(size) {
    switch (size) {
    case "xs":
      return theme.controlHeightXs;
    case "sm":
      return theme.controlHeightSm;
    case "md":
      return theme.controlHeightMd;
    case "lg":
      return theme.controlHeightLg;
    case "xl":
      return theme.controlHeightXl;
    default:
      return theme.controlHeightMd;
    }
  }

  function fontSizeFor(size) {
    switch (size) {
    case "xs":
      return theme.fontXs;
    case "sm":
      return theme.fontSm;
    case "md":
      return theme.fontMd;
    case "lg":
      return theme.fontLg;
    case "xl":
      return theme.fontXl;
    case "xxl":
      return theme.fontXxl;
    case "hero":
      return theme.fontHero;
    default:
      return theme.fontMd;
    }
  }

  function iconSizeFor(size) {
    switch (size) {
    case "xs":
      return theme.iconSizeXs;
    case "sm":
      return theme.iconSizeSm;
    case "md":
      return theme.iconSizeMd;
    case "lg":
      return theme.iconSizeLg;
    case "xl":
      return theme.iconSizeXl;
    default:
      return theme.iconSizeMd;
    }
  }

  function radiusFor(size) {
    switch (size) {
    case "none":
      return theme.radiusNone;
    case "xs":
      return theme.radiusXs;
    case "sm":
      return theme.radiusSm;
    case "md":
      return theme.radiusMd;
    case "lg":
      return theme.radiusLg;
    case "xl":
      return theme.radiusXl;
    case "full":
      return theme.radiusFull;
    default:
      return theme.radiusMd;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER FUNCTIONS (Internal logic)
  // ═══════════════════════════════════════════════════════════════════════════

  // Scale (s): Scales a base value, rounds it, and applies a minimum floor.
  // Replaces: Math.max(min, Math.round(val * baseScale))
  function s(base, min) {
    if (min === undefined)
      min = 0;
    return Math.max(min, Math.round(base * internal.scaleFactor));
  }

  function spacingFor(size) {
    switch (size) {
    case "xs":
      return theme.spacingXs;
    case "sm":
      return theme.spacingSm;
    case "md":
      return theme.spacingMd;
    case "lg":
      return theme.spacingLg;
    case "xl":
      return theme.spacingXl;
    default:
      return theme.spacingMd;
    }
  }

  // Calculates text color (black/white) based on background luminance
  function textContrast(bgColor) {
    function luminance(c) {
      return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    if (bgColor === theme.powerSaveColor)
      return "#CDD6F4";
    if (bgColor === theme.onHoverColor)
      return "#FFFFFF";

    const l = luminance(bgColor);
    return l > 0.6 ? "#4C4F69" : "#CDD6F4";
  }

  // Color opacity helper
  function withOpacity(color, opacity) {
    const base = Qt.lighter(color, 1); // ensure strings are coerced to QColor
    return Qt.rgba(base.r, base.g, base.b, opacity);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTERNAL STATE (Private)
  // ═══════════════════════════════════════════════════════════════════════════
  QtObject {
    id: internal

    readonly property var c: Config.Settings.colors
    readonly property real dpr: mainScreen ? (mainScreen.devicePixelRatio || mainScreen.scale || 1) : 1
    readonly property int height: mainScreen ? mainScreen.height : 1080
    readonly property bool isUltrawide: (width / Math.max(1, height)) > 2.1

    // Lock screen specific scale logic
    readonly property real lockScale: {
      if (height >= 1440) {
        const normalized = Math.min(1, (height - 1440) / 720);
        const heightBoost = 1.15 + normalized * 0.10;
        return isUltrawide ? heightBoost * 1.1 : heightBoost;
      }
      return isUltrawide ? 1.1 : 1.0;
    }

    // Safe access to MonitorService
    readonly property var mainScreen: (WM.MonitorService && WM.MonitorService.activeMainScreen) ? WM.MonitorService.activeMainScreen : null
    readonly property real normalizedDiagonal: {
      if (isUltrawide)
        return height * 1.87; // Simulate 16:9ish height-based diagonal
      return Math.sqrt(width * width + height * height);
    }
    readonly property real scaleFactor: {
      const diag1080 = 2203, scale1080 = 0.9;
      const diag1440 = 2938, scale1440 = 1.0;

      // Linear fit
      const m = (scale1440 - scale1080) / (diag1440 - diag1080);
      const b = scale1080 - (m * diag1080);
      const linearScale = m * normalizedDiagonal + b;

      // Dampen DPR influence
      const dprDampening = 1 + (dpr - 1) * 0.15;

      return Math.max(0.75, Math.min(1.4, linearScale * dprDampening));
    }
    readonly property int width: mainScreen ? mainScreen.width : 1920
  }
}
