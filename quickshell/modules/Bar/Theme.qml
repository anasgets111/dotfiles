pragma Singleton
import QtQuick

QtObject {
    // Panel properties

    readonly property int tooltipMaxSpace: 100
    readonly property int popupOffset: 18

    readonly property int panelRadius: 16
    readonly property int panelHeight: 42
    readonly property int panelMargin: 16
    readonly property color panelWindowColor: "transparent"
    readonly property color panelBorderColor: "#313244" // Mocha Surface2

    // Item properties
    readonly property int iconSize: 24
    readonly property int itemWidth: 34
    readonly property int itemHeight: 34
    readonly property int itemRadius: 18

    // Colors
    property color activeColor: "#CBA6F7"  // Mocha Mauve
    property color inactiveColor: "#494D64"  // Mocha Overlay0
    property color bgColor: "#1E1E2E"  // Mocha Base: Dark background
    property color onHoverColor: "#A28DCD"  // Darker Mocha Mauve for hover
    property color borderColor: "#313244"  // Mocha Surface2
    property color disabledColor: "#232634"  // Mocha Crust
    property color powerSaveColor: "#A6E3A1" // Mocha Green

    // Popup vertical offset

    // Text colors
    readonly property color textActiveColor: "#CDD6F4"  // Mocha Text: Bright for active text
    readonly property color textInactiveColor: "#A6ADC8"  // Mocha Subtext: Lighter grey for inactive text
    readonly property color textOnHoverColor: "#CBA6F7"  // Mocha Mauve: Matches activeColor for hover emphasis

    // Catppuccin contrast text color function
    function textContrast(bgColor) {
        // Catppuccin recommended text colors:
        // - Light backgrounds: "#4C4F69" (Latte text)
        // - Dark backgrounds: "#CDD6F4" (Mocha text)
        // Fallback: use luminance to decide
        function luminance(c) {
            return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
        }
        var l = luminance(bgColor);

        // If using powerSaveColor, always use Mocha text for best contrast
        if (bgColor === Theme.powerSaveColor)
            return "#CDD6F4";

        // If using onHoverColor (darker mauve), use white for best contrast
        if (bgColor === Theme.onHoverColor)
            return "#FFFFFF";

        // Threshold chosen for Catppuccin's dark/light split
        return l > 0.6 ? "#4C4F69" : "#CDD6F4";
    }

    // Font properties
    readonly property string fontFamily: "CaskaydiaCove Nerd Font Propo"
    readonly property int fontSize: 16

    // Animation
    readonly property int animationDuration: 147

    // DateTime format
    readonly property string formatDateTime: "dddd dd MMMM hh:mm AP"
}
