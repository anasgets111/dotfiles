import QtQuick

Row {
    id: centerSide
    spacing: 8

    // Shared styling properties (inherited from parent)
    property string fontFamily: parent.fontFamily || "CaskaydiaCove Nerd Font Propo"
    property color textActiveColor: parent.textActiveColor || "#ffffff"
    property color textInactiveColor: parent.textInactiveColor || "#cccccc"

    // Placeholder content for center section
    Text {
        text: "Center"
        color: textInactiveColor
        font.pixelSize: 12
        font.family: fontFamily
        anchors.verticalCenter: parent.verticalCenter
    }
}
