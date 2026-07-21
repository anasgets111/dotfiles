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
  readonly property bool _isUltrawide: internal.isUltrawide
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
  readonly property int baseVolumeExpandedWidth: 220

  // ═══════════════════════════════════════════════════════════════════════════
  // SCALED DIMENSIONS
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property int batteryPillWidth: s(baseBatteryPillWidth, 60)
  readonly property color bgColor: c.bgColor ?? "#1e1e2e"
  readonly property color bgElevated: c.bgElevated ?? Qt.lighter(bgColor, 1.35)
  readonly property color bgElevatedHover: c.bgElevatedHover ?? Qt.lighter(bgColor, 1.47)
  readonly property color bgCard: c.bgCard ?? withOpacity(bgElevated, opacitySolid)
  readonly property color bgCardHover: c.bgCardHover ?? withOpacity(bgElevatedHover, opacityStrong)
  readonly property color bgInput: c.bgInput ?? withOpacity(bgColor, opacityStrong)
  readonly property color bgOverlay: withOpacity(c.bgOverlay ?? "#000000", 0.5)
  readonly property color bgPanel: c.bgPanel ?? withOpacity(bgColor, 0.9)
  readonly property color bgSubtle: c.bgSubtle ?? withOpacity(bgColor, opacitySubtle)
  readonly property color borderColor: c.borderColor ?? "#313244"
  readonly property color borderLight: c.borderLight ?? withOpacity(borderColor, opacityMedium)
  readonly property color borderMedium: c.borderMedium ?? withOpacity(borderColor, 0.4)
  readonly property color borderSubtle: c.borderSubtle ?? withOpacity(borderColor, 0.22)
  readonly property int borderWidthMedium: 2
  readonly property real modalClosedScale: 0.97
  readonly property color modalScrimColor: c.modalScrimColor ?? bgOverlay
  readonly property real modalScrimOpacity: 0.88
  readonly property int modalMargin: spacingXl
  readonly property int modalRadius: radiusXl

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
  readonly property int controlWidthSm: s(32, 24)

  // Control Widths
  readonly property color critical: c.critical ?? "#f38ba8"
  readonly property int dialogPadding: s(20)
  readonly property int dialogWidth: s(450)
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
  readonly property int fontXl: s(20, 16)

  // Font Sizes
  readonly property int fontXs: s(10, 8)
  readonly property int fontXxl: s(28, 20)
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
  readonly property int audioPanelWidth: 380
  readonly property int audioMixerVisibleRows: 4
  readonly property int bluetoothPanelWidth: 360
  readonly property int idleModalHeight: s(760)
  readonly property int idleModalWidth: s(780)
  readonly property int idleTimeoutControlWidth: s(108)

  // Launcher
  readonly property int launcherWindowHeight: s(680)
  readonly property int launcherWindowWidth: s(860)

  // Lock Screen
  readonly property real lockClosedScale: 0.96
  readonly property color lockDividerColor: withOpacity("#ffffff", 0.08)
  readonly property color lockInnerBorderColor: withOpacity("#ffffff", 0.10)
  readonly property color lockInputBorderColor: withOpacity("#ffffff", 0.18)
  readonly property real lockScale: internal.lockScale
  readonly property color lockSurfaceBorderColor: withOpacity("#ffffff", 0.22)

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
  readonly property real opacityMuted: 0.7
  readonly property real opacitySolid: 0.6
  readonly property real opacityStrong: 0.8
  readonly property real opacitySubtle: 0.15

  // OSD
  readonly property int osdAnimationOffset: s(60)
  readonly property int osdBottomMargin: s(132)
  readonly property int osdCardHeight: s(80)
  readonly property int osdSliderTrackHeight: s(12)
  readonly property int osdSliderWidth: s(300)
  readonly property int osdToggleIconContainerSize: s(48)
  readonly property int osdToggleMinWidth: s(220)
  readonly property int panelDefaultWidth: 350
  readonly property int panelHeight: s(basePanelHeight, 28)
  readonly property int panelAnchorGap: 4
  readonly property int panelMargin: spacingMd
  readonly property int panelRadius: radiusMd
  readonly property int panelScreenInset: 8
  readonly property int panelToggleCompactThreshold: s(220)
  readonly property int panelToggleCardHeight: s(56)
  readonly property int popupOffset: spacingMd
  readonly property color powerSaveColor: c.powerSaveColor ?? "#a6e3a1"
  readonly property int radiusFull: 9999
  readonly property int radiusLg: s(baseItemRadius, 12)
  readonly property int radiusMd: s(12, 8)

  // Radii
  readonly property int radiusSm: s(6, 4)
  readonly property int radiusXl: s(40, 20)
  readonly property int radiusXs: s(3, 2)
  // ═══════════════════════════════════════════════════════════════════════════
  // SCALE PRESETS
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property real scaleSmall: 0.7
  readonly property int shadowBlurLg: 32
  readonly property int shadowBlurMd: 20

  // ═══════════════════════════════════════════════════════════════════════════
  // SHADOW
  // ═══════════════════════════════════════════════════════════════════════════
  readonly property color shadowColorStrong: withOpacity(c.shadowColorStrong ?? "#000000", 0.55)
  readonly property int shadowOffsetY: 2
  readonly property int spinnerDuration: 1000
  readonly property int spinnerSize: controlHeightSm
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
  readonly property int volumeExpandedWidth: s(baseVolumeExpandedWidth, 140)
  readonly property int wallpaperAnimationDuration: 900
  readonly property int wallpaperModalHeight: s(650)
  readonly property int wallpaperModalWidth: s(1040)
  readonly property int wallpaperSidebarWidth: s(250)
  readonly property int wallpaperTileWidth: s(230)
  readonly property int networkPanelWidth: 340
  readonly property int notificationPanelWidth: 420
  readonly property int trayMenuWidth: 300
  readonly property int updateLogVisibleRows: 15
  readonly property int updateOldVersionColumnWidth: 125
  readonly property int updatePackageColumnWidth: 190
  readonly property int updateTableVisibleRows: 11
  readonly property int updatePanelWidth: 500
  readonly property color warning: c.warning ?? "#fab387"

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  function controlHeightFor(size) {
    return _controlHeights[size] ?? controlHeightMd;
  }
  function textContrast(background: color): color {
    const value = Qt.color(background);
    const linear = channel => channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
    const luminance = 0.2126 * linear(value.r) + 0.7152 * linear(value.g) + 0.0722 * linear(value.b);
    return luminance > 0.179 ? "#000000" : "#ffffff";
  }
  function fontSizeFor(size) {
    return _fontSizes[size] ?? fontMd;
  }
  function iconSizeFor(size) {
    return _iconSizes[size] ?? iconSizeMd;
  }
  function s(base, min = 0) {
    return Math.max(min, Math.round(base * internal.scaleFactor));
  }
  function spacingFor(size) {
    return _spacings[size] ?? spacingMd;
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
      // Lock screen scaling uses effective (perceived) height so dpr doesn't double-boost.
      const effectiveHeight = height / dpr;
      if (effectiveHeight >= 1440) {
        const normalized = Math.min(1, (effectiveHeight - 1440) / 720);
        const heightBoost = 1.15 + normalized * 0.10;
        return isUltrawide ? heightBoost * 1.1 : heightBoost;
      }
      return isUltrawide ? 1.1 : 1.0;
    }
    readonly property var mainScreen: MonitorService?.activeMainScreen ?? null
    readonly property real scaleFactor: {
      // Calculate perceived height to avoid double-scaling on high-DPI screens.
      // Example: 4K (2160p) at 2x -> 1080 effective height.
      const effectiveHeight = height / dpr;
      // Map effective height to a scale preference:
      // 1080p effective -> 0.9 (compact), 1440p effective -> 1.0 (standard).
      // Formula: 0.9 + (diff_from_1080 / 360) * 0.1
      const hScale = 0.9 + ((effectiveHeight - 1080) / 360) * 0.1;
      // Clamp to keep layouts stable on extreme sizes.
      return Math.max(0.75, Math.min(1.4, hScale));
    }
    readonly property int width: mainScreen?.width ?? 1920
  }
}
