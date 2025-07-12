pragma Singleton
import QtQuick

QtObject {
    // Panel properties
    property int panelRadius: 15
    property int panelHeight: 40
    property int panelMargin: 16
    property color panelWindowColor: "transparent"
    property color panelBorderColor: "#333333"

    // Item properties
    property int itemWidth: 32
    property int itemHeight: 24
    property int itemRadius: 15
    property int borderWidth: 2

    // Colors
    property color activeColor: "#CBA6E2"  // Mauve: Vibrant accent for active elements
    property color inactiveColor: "#494D64"  // Overlay0: Muted grey for inactive states
    property color bgColor: "#1E1E2E"  // Base: Dark background for overall theme
    property color onHoverColor: "#F5C2E7"  // Rosewater: Soft highlight for hover, related to Mauve for cohesion
    property color borderColor: "#313244"  // Surface2: Subtle border color for UI elements

    // Text colors
    property color textActiveColor: "#CDD6F4"  // Text: Bright white for active text
    property color textInactiveColor: "#A6ADC8"  // Subtext: Lighter grey for inactive text
    property color textOnHoverColor: "#CBA6E2"  // Mauve: Matches activeColor for hover emphasis
    // Font properties
    property string fontFamily: "CaskaydiaCove Nerd Font Propo"
    property int fontSize: 14

    // Animation
    property int animationDuration: 147


    // DateTime format
    property string formatDateTime: "yyyy-MM-dd dddd hh:mm AP"
}
