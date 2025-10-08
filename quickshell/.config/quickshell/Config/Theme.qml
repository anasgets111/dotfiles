pragma Singleton
import Quickshell
import QtQuick
import qs.Services.WM as WM

Singleton {
  id: theme

  // --- Responsive scaling prototype ---
  // We derive a baseScale from the active main monitor via MonitorService.
  // This is an initial test implementation: keep legacy fixed constants for now.
  // Formula: start from a resolution category factor, multiply by monitor scale (devicePixelRatio) moderation,
  // then clamp. Later we can migrate size tokens to use this.
  // Access via WM.MonitorService singleton
  readonly property var _mainScreen: (WM.MonitorService && WM.MonitorService.activeMainScreen) ? WM.MonitorService.activeMainScreen : null
  readonly property int _msw: _mainScreen ? _mainScreen.width : 1920
  readonly property int _msh: _mainScreen ? _mainScreen.height : 1080
  readonly property real _mss: _mainScreen ? (_mainScreen.devicePixelRatio || _mainScreen.scale || 1.0) : 1.0
  // Compute a diagonal-based scale using pixel diagonal and device pixel ratio (DPR).
  // This produces a smooth, monotonic scale so smaller physical/low-res screens get
  // a smaller UI and larger/high-DPI screens scale up. We dampen DPR so HiDPI
  // doesn't double-inflate sizes.
  readonly property real _screenWidthPx: _msw
  readonly property real _screenHeightPx: _msh
  readonly property real _devicePixelRatio: _mss

  // Diagonal in physical pixels (approx): sqrt(w^2 + h^2) * DPR
  readonly property real _diagonalPixels: Math.sqrt(_screenWidthPx * _screenWidthPx + _screenHeightPx * _screenHeightPx) * _devicePixelRatio

  // Map diagonalPixels to a scale value using linear mapping + clamps.
  // Tunable breakpoints: small laptops -> ~0.86, common 1080/1440 monitors -> ~0.95..1.12, 4K -> ~1.28
  readonly property real baseScale: {
    const diag = _diagonalPixels;
    // Target calibration points (approx):
    // - 1920x1080 -> diagonal ~2203 px -> prefer scale ~= 0.90
    // - 2560x1440 -> diagonal ~2938 px -> prefer scale ~= 1.00
    const diag1080 = 2203.0;
    const diag1440 = 2938.0;
    const scaleAt1080 = 0.90;
    const scaleAt1440 = 1.00;

    // Linear mapping coefficients: scale = a * diag + b
    const a = (scaleAt1440 - scaleAt1080) / (diag1440 - diag1080);
    const b = scaleAt1080 - (a * diag1080);

    let mappedScale = a * diag + b;

    // Damp additional DPR influence so very high DPRs don't over-scale
    const dampenedDprFactor = 1.0 + (_devicePixelRatio - 1.0) * 0.25;
    const combined = mappedScale * dampenedDprFactor;

    // Final clamp to reasonable bounds
    return Math.max(0.75, Math.min(1.4, combined));
  }

  readonly property int animationDuration: 147
  readonly property color activeColor: "#CBA6F7"
  readonly property color bgColor: "#1E1E2E"
  readonly property color borderColor: "#313244"
  readonly property color disabledColor: "#232634"
  readonly property color inactiveColor: "#494D64"
  readonly property color onHoverColor: "#A28DCD"
  readonly property color critical: "#f38ba8"
  readonly property color warning: "#fab387"
  readonly property color powerSaveColor: "#A6E3A1"
  readonly property color textActiveColor: "#CDD6F4"
  readonly property color textInactiveColor: "#A6ADC8"
  readonly property color textOnHoverColor: "#CBA6F7"
  readonly property color panelWindowColor: "transparent"
  readonly property string fontFamily: "CaskaydiaCove Nerd Font Propo"
  readonly property string formatDateTime: " dd dddd hh:mm AP"

  // Base (unscaled) token values — used to compute scaled tokens below.
  readonly property int baseFontSize: 16
  readonly property int baseIconSize: 24
  readonly property int baseItemHeight: 34
  readonly property int baseItemRadius: 18
  readonly property int baseItemWidth: 34
  readonly property int basePanelHeight: 42
  // New: base widths for widgets that were previously hardcoded
  readonly property int baseBatteryPillWidth: 80
  readonly property int baseVolumeExpandedWidth: 220

  // Public tokens (scaled automatically). Widgets can keep using Theme.fontSize etc.
  readonly property int fontSize: Math.max(10, Math.round(baseFontSize * baseScale))
  readonly property int iconSize: Math.max(12, Math.round(baseIconSize * baseScale))
  readonly property int itemHeight: Math.max(20, Math.round(baseItemHeight * baseScale))
  readonly property int itemRadius: Math.max(6, Math.round(baseItemRadius * baseScale))
  readonly property int itemWidth: Math.max(20, Math.round(baseItemWidth * baseScale))
  readonly property int panelHeight: Math.max(28, Math.round(basePanelHeight * baseScale))
  // New: centralized widths
  readonly property int batteryPillWidth: Math.max(60, Math.round(baseBatteryPillWidth * baseScale))
  readonly property int volumeExpandedWidth: Math.max(140, Math.round(baseVolumeExpandedWidth * baseScale))
  readonly property int panelMargin: 12
  readonly property int panelRadius: 12
  readonly property int popupOffset: 12
  readonly property int tooltipMaxSpace: 100

  // Backwards-compatible aliases (some widgets may reference these names)
  readonly property int fontSizeScaled: fontSize
  readonly property int iconSizeScaled: iconSize
  readonly property int itemHeightScaled: itemHeight
  readonly property int itemRadiusScaled: itemRadius
  readonly property int itemWidthScaled: itemWidth
  readonly property int panelHeightScaled: panelHeight

  function textContrast(bgColor) {
    function luminance(c) {
      return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    var l = luminance(bgColor);
    if (bgColor === theme.powerSaveColor)
      return "#CDD6F4";

    if (bgColor === theme.onHoverColor)
      return "#FFFFFF";

    return l > 0.6 ? "#4C4F69" : "#CDD6F4";
  }
}
