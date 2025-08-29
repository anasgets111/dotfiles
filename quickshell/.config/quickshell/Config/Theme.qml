pragma Singleton
import Quickshell
import QtQuick

Singleton {
  id: theme

  property color activeColor: "#CBA6F7"
  readonly property int animationDuration: 147
  property color bgColor: "#1E1E2E"
  property color borderColor: "#313244"
  property color disabledColor: "#232634"
  readonly property string fontFamily: "CaskaydiaCove Nerd Font Propo"
  readonly property int fontSize: 16
  readonly property string formatDateTime: " dd dddd hh:mm AP"
  readonly property int iconSize: 24
  property color inactiveColor: "#494D64"
  readonly property int itemHeight: 34
  readonly property int itemRadius: 18
  readonly property int itemWidth: 34
  property color onHoverColor: "#A28DCD"
  readonly property color panelColor: "#313244"
  readonly property int panelHeight: 42
  readonly property int panelMargin: 16
  readonly property int panelRadius: 16
  readonly property color panelWindowColor: "transparent"
  readonly property int popupOffset: 18
  property color powerSaveColor: "#A6E3A1"
  readonly property color textActiveColor: "#CDD6F4"
  readonly property color textInactiveColor: "#A6ADC8"
  readonly property color textOnHoverColor: "#CBA6F7"
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
