pragma Singleton
import QtQuick

QtObject {
    property int panelRadius: 15
    property int panelHeight: 40
    property int panelMargin: 16
    property color panelWindowColor: "transparent"
    property string fontFamily:       "CaskaydiaCove Nerd Font Propo"
    property int    itemWidth:        32
    property int    itemHeight:       24
    property int    wsRadius:         15
    property color  activeColor:      "#4a9eff"
    property color  inactiveColor:    "#333333"
    property int    fontWeight:        Font.Bold
    property color  borderColor:      "#555555"
    property color  bgColor:          "#1a1a1a"
    property color  panelBorderColor: "#333333"
    property color  textActiveColor:  "#ffffff"
    property color  textInactiveColor:"#cccccc"
    property int    animationDuration:250
    property int    borderWidth:      2
    property int    fontSize:         14
}
