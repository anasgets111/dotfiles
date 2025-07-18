import QtQuick

Row {
    id: leftSide
    spacing: 8

    property bool normalWorkspacesExpanded: false

    PowerMenu {
        anchors.verticalCenter: parent.verticalCenter
    }

    UpdateChecker {
        anchors.verticalCenter: parent.verticalCenter
    }

    IdleInhibitor {
        id: idleInhibitor
        anchors.verticalCenter: parent.verticalCenter
    }

    KeyboardLayoutIndicator {
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
        expanded: leftSide.normalWorkspacesExpanded
        onExpandedChanged: leftSide.normalWorkspacesExpanded = expanded
    }
}
