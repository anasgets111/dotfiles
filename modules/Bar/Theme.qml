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
    property color activeColor: "#4a9eff"
    property color inactiveColor: "#333333"
    property color bgColor: "#1a1a1a"
    property color onHoverColor: "#5aafff"
    property color borderColor: "#333333"

    // Text colors
    property color textActiveColor: "#ffffff"
    property color textInactiveColor: "#cccccc"

    // Font properties
    property string fontFamily: "CaskaydiaCove Nerd Font Propo"
    property int fontSize: 14

    // Animation
    property int animationDuration: 250


    // DateTime format
    property string formatDateTime: "yyyy-MM-dd dddd hh:mm AP"
}
