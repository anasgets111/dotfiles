pragma Singleton
import QtQuick

QtObject {
    readonly property int tooltipMaxSpace: 100
    readonly property int popupOffset: 18
    readonly property int panelRadius: 16
    readonly property int panelHeight: 42
    readonly property int panelMargin: 16
    readonly property color panelWindowColor: "transparent"
    readonly property color panelColor: "#313244"
    readonly property int iconSize: 24
    readonly property int itemWidth: 34
    readonly property int itemHeight: 34
    readonly property int itemRadius: 18

    property color activeColor: "#CBA6F7"
    property color inactiveColor: "#494D64"
    property color bgColor: "#1E1E2E"
    property color onHoverColor: "#A28DCD"
    property color borderColor: "#313244"
    property color disabledColor: "#232634"
    property color powerSaveColor: "#A6E3A1"
    readonly property color textActiveColor: "#CDD6F4"
    readonly property color textInactiveColor: "#A6ADC8"
    readonly property color textOnHoverColor: "#CBA6F7"
    readonly property string fontFamily: "CaskaydiaCove Nerd Font Propo"
    readonly property int fontSize: 16
    readonly property int animationDuration: 147
    readonly property string formatDateTime: " dd dddd hh:mm AP"

    function textContrast(bgColor) {
        function luminance(c) {
            return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
        }

        var l = luminance(bgColor);
        if (bgColor === Theme.powerSaveColor)
            return "#CDD6F4";

        if (bgColor === Theme.onHoverColor)
            return "#FFFFFF";

        return l > 0.6 ? "#4C4F69" : "#CDD6F4";
    }
}
