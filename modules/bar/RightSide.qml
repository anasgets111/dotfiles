import QtQuick

Row {
    id: rightSide
    spacing: 8

    // Shared styling properties (inherited from parent)
    property string fontFamily: parent.fontFamily || "CaskaydiaCove Nerd Font Propo"
    property color textActiveColor: parent.textActiveColor || "#ffffff"
    property color textInactiveColor: parent.textInactiveColor || "#cccccc"
    property int fontSize: parent.fontSize || 12

    // Placeholder content for right section
    Text {
        text: "Right"
        color: textInactiveColor
        font.pixelSize: fontSize
        font.family: fontFamily
        anchors.verticalCenter: parent.verticalCenter
    }
}
