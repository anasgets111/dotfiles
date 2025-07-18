pragma Singleton
import QtQuick

QtObject {
    // Panel properties

    readonly property int tooltipMaxSpace: 100
    readonly property int panelRadius: 15
    readonly property int panelHeight: 40
    readonly property int panelMargin: 16
    readonly property color panelWindowColor: "transparent"
    readonly property color panelBorderColor: "#333333"

    // Item properties
    readonly property int itemWidth: 32
    readonly property int itemHeight: 24
    readonly property int itemRadius: 12
    readonly property int borderWidth: 2
    readonly property int cornerRadius : 12

    // Colors
    property color activeColor: "#CBA6E2"  // Mauve: Vibrant accent for active elements
    property color inactiveColor: "#494D64"  // Overlay0: Muted grey for inactive states
    property color bgColor: "#1E1E2E"  // Base: Dark background for overall theme
    property color onHoverColor: "#F5C2E7"  // Rosewater: Soft highlight for hover, related to Mauve for cohesion
    property color borderColor: "#313244"  // Surface2: Subtle border color for UI elements
    property color disabledColor: "#232634"  // Disabled: Dimmed color for unavailable/unpopulated workspaces
    property color powerSaveColor: "#a6e3a1"

    // Popup vertical offset
    readonly property int popupOffset: 17

    // Text colors
    readonly property color textActiveColor: "#CDD6F4"  // Text: Bright white for active text
    readonly property color textInactiveColor: "#A6ADC8"  // Subtext: Lighter grey for inactive text
    readonly property color textOnHoverColor: "#CBA6E2"  // Mauve: Matches activeColor for hover emphasis

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
        // Threshold chosen for Catppuccin's dark/light split
        return l > 0.5 ? "#4C4F69" : "#CDD6F4";
    }

    // Font properties
    readonly property string fontFamily: "CaskaydiaCove Nerd Font Propo"
    readonly property int fontSize: 17

    // Animation
    readonly property int animationDuration: 147


    // DateTime format
    readonly property string formatDateTime: "dddd dd MMMM hh:mm AP"
}
