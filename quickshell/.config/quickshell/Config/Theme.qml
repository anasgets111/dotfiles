pragma Singleton
import QtQuick
import Quickshell
import qs.Config
import qs.Services.WM

Singleton {
  id: theme

  // ═══════════════════════════════════════════════════════════════════════════
  // LOOKUP MAPS (for *For functions)
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property var _controlHeights: ({
      xs: controlHeightXs,
      sm: controlHeightSm,
      md: controlHeightMd,
      lg: controlHeightLg,
      xl: controlHeightXl
    })
  readonly property var _fontSizes: ({
      xs: fontXs,
      sm: fontSm,
      md: fontMd,
      lg: fontLg,
      xl: fontXl,
      xxl: fontXxl,
      hero: fontHero
    })
  readonly property var _iconSizes: ({
      xs: iconSizeXs,
      sm: iconSizeSm,
      md: iconSizeMd,
      lg: iconSizeLg,
      xl: iconSizeXl
    })
  readonly property var _radii: ({
      none: radiusNone,
      xs: radiusXs,
      sm: radiusSm,
      md: radiusMd,
      lg: radiusLg,
      xl: radiusXl,
      full: radiusFull
    })
  readonly property var _spacings: ({
      xs: spacingXs,
      sm: spacingSm,
      md: spacingMd,
      lg: spacingLg,
      xl: spacingXl
    })

  // ═══════════════════════════════════════════════════════════════════════════
  // BASE COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property color activeColor: c.activeColor ?? "#cba6f7"

  // ═══════════════════════════════════════════════════════════════════════════
  // DERIVED COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property color activeFull: c.activeFull ?? withOpacity(activeColor, opacityFull)
  readonly property color activeLight: c.activeLight ?? withOpacity(activeColor, opacityLight)
  readonly property color activeMedium: c.activeMedium ?? withOpacity(activeColor, opacityMedium)
  readonly property color activeSubtle: c.activeSubtle ?? withOpacity(activeColor, opacitySubtle)

  // ═══════════════════════════════════════════════════════════════════════════
  // ANIMATION
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property int animationDuration: 147
  readonly property int animationFast: 100
  readonly property int animationSlow: 250
  readonly property int animationVerySlow: 400

  // ═══════════════════════════════════════════════════════════════════════════
  // BASE SIZES (Unscaled)
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property int baseBatteryPillWidth: 80
  readonly property int baseFontSize: 16
  readonly property int baseIconSize: 24
  readonly property int baseItemHeight: 34
  readonly property int baseItemRadius: 18
  readonly property int baseItemWidth: 34
  readonly property int basePanelHeight: 42

  // ═══════════════════════════════════════════════════════════════════════════
  // SCALING
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property real baseScale: internal.scaleFactor
  readonly property int baseVolumeExpandedWidth: 220

  // ═══════════════════════════════════════════════════════════════════════════
  // SCALED DIMENSIONS
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property int batteryPillWidth: s(baseBatteryPillWidth, 60)
  readonly property color bgCard: c.bgCard ?? withOpacity(bgColor, opacitySolid)
  readonly property color bgColor: c.bgColor ?? "#1e1e2e"
  readonly property color bgElevated: c.bgElevated ?? Qt.lighter(bgColor, 1.35)
  readonly property color bgElevatedAlt: c.bgElevatedAlt ?? Qt.lighter(bgColor, 1.25)
  readonly property color bgElevatedHover: c.bgElevatedHover ?? Qt.lighter(bgColor, 1.47)
  readonly property color bgInput: c.bgInput ?? withOpacity(bgColor, opacityStrong)
  readonly property color bgOverlay: withOpacity(c.bgOverlay ?? "#000000", 0.5)
  readonly property color bgSubtle: c.bgSubtle ?? withOpacity(bgColor, opacitySubtle)
  readonly property color borderColor: c.borderColor ?? "#313244"
  readonly property color borderLight: c.borderLight ?? withOpacity(borderColor, opacityMedium)
  readonly property color borderMedium: c.borderMedium ?? withOpacity(borderColor, 0.4)
  readonly property color borderStrong: c.borderStrong ?? withOpacity(borderColor, opacityDisabled)
  readonly property color borderSubtle: c.borderSubtle ?? withOpacity(borderColor, 0.22)
  readonly property int borderWidthMedium: 2
  readonly property int borderWidthThick: 3

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDER
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property int borderWidthThin: 1

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIG ACCESSOR
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property var c: Settings?.colors ?? {}
  readonly property int cardPadding: s(10)
  readonly property int controlHeightLg: s(basePanelHeight, 34)
  readonly property int controlHeightMd: s(baseItemHeight, 28)
  readonly property int controlHeightSm: s(28, 24)
  readonly property int controlHeightXl: s(52, 42)

  // Control Heights
  readonly property int controlHeightXs: s(24, 20)
  readonly property int controlWidthLg: s(48, 40)
  readonly property int controlWidthMd: s(baseItemWidth, 28)
  readonly property int controlWidthSm: s(32, 24)
  readonly property int controlWidthXl: s(64, 52)

  // Control Widths
  readonly property int controlWidthXs: s(24, 20)
  readonly property color critical: c.critical ?? "#f38ba8"
  readonly property int dialogPadding: s(20)
  readonly property real dialogWidthRatio: internal.isUltrawide ? 0.45 : 0.6
  readonly property color disabledColor: c.disabledColor ?? "#232634"

  // ═══════════════════════════════════════════════════════════════════════════
  // TYPOGRAPHY
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property string fontFamily: "CaskaydiaCove Nerd Font Propo"
  readonly property int fontHero: s(48, 32)
  readonly property int fontLg: s(16, 14)
  readonly property int fontMd: s(14, 12)
  readonly property int fontSize: s(baseFontSize, 10)
  readonly property int fontSm: s(12, 10)
  readonly property int fontWeightBold: Font.Bold
  readonly property int fontWeightLight: Font.Light
  readonly property int fontWeightMedium: Font.Medium
  readonly property int fontWeightNormal: Font.Normal
  readonly property int fontWeightSemiBold: Font.DemiBold
  readonly property int fontXl: s(20, 16)

  // Font Sizes
  readonly property int fontXs: s(10, 8)
  readonly property int fontXxl: s(28, 20)
  readonly property string formatDateTime: " dd dddd hh:mm AP"
  readonly property string iconFontFamily: "JetBrainsMono Nerd Font Mono"
  readonly property int iconSize: s(baseIconSize, 12)
  readonly property int iconSizeLg: s(24, 18)
  readonly property int iconSizeMd: s(18, 14)
  readonly property int iconSizeSm: s(14, 12)
  readonly property int iconSizeXl: s(32, 24)

  // Icon Sizes
  readonly property int iconSizeXs: s(12, 10)
  readonly property color inactiveColor: c.inactiveColor ?? "#494d64"
  readonly property int itemHeight: s(baseItemHeight, 20)
  readonly property int itemRadius: s(baseItemRadius, 6)
  readonly property int itemWidth: s(baseItemWidth, 20)

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGET SPECIFICS
  // ═══════════════════════════════════════════════════════════════════════════
  // Launcher
  readonly property int launcherCellSize: s(150)
  readonly property int launcherIconSize: s(72)
  readonly property int launcherWindowHeight: s(471)
  readonly property int launcherWindowWidth: s(741)

  // Lock Screen
  readonly property int lockCardContentWidth: Math.round(400 * baseScale * lockScale)
  readonly property int lockCardMaxWidth: Math.round(500 * baseScale * lockScale)
  readonly property real lockScale: internal.lockScale

  // Notifications
  readonly property int notificationAppIconSize: s(40)
  readonly property int notificationCardWidth: s(380)
  readonly property int notificationInlineImageSize: s(24)
  readonly property color onHoverColor: c.onHoverColor ?? "#a28dcd"

  // ═══════════════════════════════════════════════════════════════════════════
  // OPACITY CONSTANTS
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property real opacityDisabled: 0.5
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
  readonly property color panelWindowColor: c.panelWindowColor ?? "transparent"
  readonly property int popupOffset: spacingMd
  readonly property color powerSaveColor: c.powerSaveColor ?? "#a6e3a1"
  readonly property int radiusFull: 9999
  readonly property int radiusLg: s(baseItemRadius, 12)
  readonly property int radiusMd: s(12, 8)

  // Radii
  readonly property int radiusNone: 0
  readonly property int radiusSm: s(6, 4)
  readonly property int radiusXl: s(40, 20)
  readonly property int radiusXs: s(3, 2)
  readonly property real scaleExtraLarge: 1.5
  readonly property real scaleLarge: 1.2
  readonly property real scaleMedium: 0.9
  readonly property real scaleMediumSmall: 0.8
  readonly property real scaleNormal: 1.0

  // ═══════════════════════════════════════════════════════════════════════════
  // SCALE PRESETS
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property real scaleSmall: 0.7
  readonly property int scrollBarWidth: spacingSm
  readonly property int shadowBlurLg: 32
  readonly property int shadowBlurMd: 20

  // ═══════════════════════════════════════════════════════════════════════════
  // SHADOW
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property int shadowBlurSm: 8
  readonly property color shadowColor: withOpacity(c.shadowColor ?? "#000000", 0.2)
  readonly property color shadowColorStrong: withOpacity(c.shadowColorStrong ?? "#000000", 0.55)
  readonly property int shadowOffsetY: 2
  readonly property int spacingLg: s(16)
  readonly property int spacingMd: s(12)
  readonly property int spacingSm: s(8)
  readonly property int spacingXl: s(24)

  // Spacing
  readonly property int spacingXs: s(4)
  readonly property color textActiveColor: c.textActiveColor ?? "#cdd6f4"
  readonly property color textDisabled: c.textDisabled ?? withOpacity(textInactiveColor, opacityMedium)
  readonly property color textInactiveColor: c.textInactiveColor ?? "#a6adc8"
  readonly property color textOnHoverColor: c.textOnHoverColor ?? "#cba6f7"
  readonly property int tooltipMaxSpace: 100
  readonly property int volumeExpandedWidth: s(baseVolumeExpandedWidth, 140)
  readonly property color warning: c.warning ?? "#fab387"

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  function controlHeightFor(size) {
    return _controlHeights[size] ?? controlHeightMd;
  }

  function fontSizeFor(size) {
    return _fontSizes[size] ?? fontMd;
  }

  function iconSizeFor(size) {
    return _iconSizes[size] ?? iconSizeMd;
  }

  function radiusFor(size) {
    return _radii[size] ?? radiusMd;
  }

  function s(base, min = 0) {
    return Math.max(min, Math.round(base * internal.scaleFactor));
  }

  function spacingFor(size) {
    return _spacings[size] ?? spacingMd;
  }

  function textContrast(bgColor) {
    if (bgColor === powerSaveColor)
      return textActiveColor;
    if (bgColor === onHoverColor)
      return "#FFFFFF";
    const lum = 0.299 * bgColor.r + 0.587 * bgColor.g + 0.114 * bgColor.b;
    return lum > 0.6 ? "#4C4F69" : textActiveColor;
  }

  function withOpacity(color, opacity) {
    if (!color)
      return "transparent";
    const c = Qt.color(color);
    return Qt.rgba(c.r, c.g, c.b, opacity);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTERNAL STATE
  // ═══════════════════════════════════════════════════════════════════════════
  QtObject {
    id: internal

    readonly property real dpr: mainScreen?.devicePixelRatio ?? mainScreen?.scale ?? 1
    readonly property int height: mainScreen?.height ?? 1080
    readonly property bool isUltrawide: (width / Math.max(1, height)) > 2.1
    readonly property real lockScale: {
      if (height >= 1440) {
        const normalized = Math.min(1, (height - 1440) / 720);
        const heightBoost = 1.15 + normalized * 0.10;
        return isUltrawide ? heightBoost * 1.1 : heightBoost;
      }
      return isUltrawide ? 1.1 : 1.0;
    }
    readonly property var mainScreen: MonitorService?.activeMainScreen ?? null
    readonly property real normalizedDiagonal: isUltrawide ? height * 1.87 : Math.sqrt(width * width + height * height)
    readonly property real scaleFactor: {
      const diag1080 = 2203, scale1080 = 0.9;
      const diag1440 = 2938, scale1440 = 1.0;
      const m = (scale1440 - scale1080) / (diag1440 - diag1080);
      const linearScale = m * normalizedDiagonal + (scale1080 - m * diag1080);
      const dprDampening = 1 + (dpr - 1) * 0.15;
      return Math.max(0.75, Math.min(1.4, linearScale * dprDampening));
    }
    readonly property int width: mainScreen?.width ?? 1920
  }
}
