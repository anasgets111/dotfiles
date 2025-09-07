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
  // Step scale by width; simple buckets for now
  function _resBucketScale(w, h) {
    if (w <= 1920)
      return 1.00;
    if (w <= 2560)
      return 1.12; // 1440p typical
    if (w <= 3440)
      return 1.20; // ultrawide 1440p
    if (w <= 3840)
      return 1.32; // 4K
    return 1.42; // >4K
  }
  // Combine bucket with device scale but dampen device scale so HiDPI doesn't double-inflate
  readonly property real baseScale: {
    const bucket = _resBucketScale(_msw, _msh);
    const dpr = _mss; // usually 1 or 2
    const dprFactor = 1 + (dpr - 1) * 0.35; // only take 35% of extra DPR
    const combined = bucket * dprFactor;
    return Math.min(1.6, Math.max(1.0, combined));
  }

  readonly property int animationDuration: 147
  readonly property color activeColor: "#CBA6F7"
  readonly property color bgColor: "#F31E1E2E" // ~80% opaque
  readonly property color borderColor: "#313244"
  readonly property color disabledColor: "#232634"
  readonly property color inactiveColor: "#494D64"
  readonly property color onHoverColor: "#A28DCD"
  readonly property color powerSaveColor: "#A6E3A1"
  readonly property color textActiveColor: "#CDD6F4"
  readonly property color textInactiveColor: "#A6ADC8"
  readonly property color textOnHoverColor: "#CBA6F7"
  readonly property color panelWindowColor: "transparent"
  readonly property string fontFamily: "CaskaydiaCove Nerd Font Propo"
  readonly property string formatDateTime: " dd dddd hh:mm AP"
  readonly property int fontSize: 16
  readonly property int iconSize: 24
  readonly property int itemHeight: 34
  readonly property int itemRadius: 18
  readonly property int itemWidth: 34
  readonly property int panelHeight: 42
  readonly property int panelMargin: 16
  readonly property int panelRadius: 16
  readonly property int popupOffset: 18
  readonly property int tooltipMaxSpace: 100

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
