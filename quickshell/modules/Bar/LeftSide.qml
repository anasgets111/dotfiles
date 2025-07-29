import QtQuick

Row {
    id: leftSide

    property bool normalWorkspacesExpanded: false

    spacing: 8

    PowerMenu {
        anchors.verticalCenter: parent.verticalCenter
    }

    Loader {
        active: DetectEnv.distroId === "arch"

        sourceComponent: ArchChecker {
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    IdleInhibitor {
        id: idleInhibitor

        anchors.verticalCenter: parent.verticalCenter
    }

    KeyboardLayoutIndicator {
        anchors.verticalCenter: parent.verticalCenter
    }

    Loader {
        active: DetectEnv.isLaptopBattery

        sourceComponent: BatteryIndicator {
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Loader {
        active: DetectEnv.isNiri

        sourceComponent: NiriWorkspaces {
            id: niriWorkspaces

            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Loader {
        active: DetectEnv.isHyprland

        sourceComponent: SpecialWorkspaces {
            id: specialWorkspaces

            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Loader {
        active: DetectEnv.isHyprland

        sourceComponent: NormalWorkspaces {
            id: normalWorkspaces

            anchors.verticalCenter: parent.verticalCenter
            expanded: leftSide.normalWorkspacesExpanded
            onExpandedChanged: leftSide.normalWorkspacesExpanded = expanded
        }
    }
}
