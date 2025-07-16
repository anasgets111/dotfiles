import QtQuick


Row {
    id: leftSide
    spacing: 8

    IdleInhibitor {
        id: idleInhibitor
        anchors.verticalCenter: parent.verticalCenter
    }

    KeyboardLayoutIndicator{
        anchors.verticalCenter: parent.verticalCenter
    }
    BatteryIndicator {
        anchors.verticalCenter: parent.verticalCenter
    }

    SpecialWorkspaces {
        id: specialWorkspaces
        anchors.verticalCenter: parent.verticalCenter
    }

    NormalWorkspaces {
        id: normalWorkspaces
        anchors.verticalCenter: parent.verticalCenter
    }
}
