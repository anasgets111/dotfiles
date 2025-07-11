import QtQuick

Row {
    id: leftSide
    spacing: 8

    // Shared styling properties (inherited from parent)
    property string fontFamily: parent.fontFamily || "CaskaydiaCove Nerd Font Propo"
    property int wsWidth: parent.wsWidth || 32
    property int wsHeight: parent.wsHeight || 24
    property int wsRadius: parent.wsRadius || 15
    property color activeColor: parent.activeColor || "#4a9eff"
    property color inactiveColor: parent.inactiveColor || "#333333"
    property color borderColor: parent.borderColor || "#555555"
    property color textActiveColor: parent.textActiveColor || "#ffffff"
    property color textInactiveColor: parent.textInactiveColor || "#cccccc"
    property int animationDuration: parent.animationDuration || 250
    property int borderWidth: parent.borderWidth || 2

    // Idle inhibitor for PowerSave
    IdleInhibitor {
        id: idleInhibitor
        anchors.verticalCenter: parent.verticalCenter
    }

    // Normal workspaces module
    NormalWorkspaces {
        id: normalWorkspaces
        anchors.verticalCenter: parent.verticalCenter
    }

    // Special workspaces module
    SpecialWorkspaces {
        id: specialWorkspaces
        anchors.verticalCenter: parent.verticalCenter
    }
}
