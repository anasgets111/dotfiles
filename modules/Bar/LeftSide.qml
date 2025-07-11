import QtQuick


Row {
    id: leftSide
    spacing: 8

    // Styling properties are now accessed from Theme singleton

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
