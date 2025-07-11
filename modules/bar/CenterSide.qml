import QtQuick

Row {
    id: centerSide
    spacing: 8

    // Shared styling properties (inherited from parent)
    property string fontFamily: parent.fontFamily || "CaskaydiaCove Nerd Font Propo"
    property color textActiveColor: parent.textActiveColor || "#ffffff"
    property color textInactiveColor: parent.textInactiveColor || "#cccccc"
    property int fontSize: parent.fontSize || 12

    // Active window title display
    ActiveWindow {
        id: activeWindowTitle
        anchors.verticalCenter: parent.verticalCenter
    }
}
