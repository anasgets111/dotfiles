import QtQuick

Loader {
    id: layoutLoader
    active: true
    sourceComponent: verticalMode ? columnLayout : rowLayout
    property bool verticalMode: false
    property bool normalWorkspacesExpanded: false

    Component {
        id: rowLayout
        Row {
            id: leftSide
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
                    expanded: layoutLoader.normalWorkspacesExpanded
                    onExpandedChanged: layoutLoader.normalWorkspacesExpanded = expanded
                }
            }
        }
    }

    Component {
        id: columnLayout
        Column {
            id: leftSideVertical
            spacing: 8

            PowerMenu {
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Loader {
                active: DetectEnv.distroId === "arch"
                sourceComponent: ArchChecker {
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            IdleInhibitor {
                id: idleInhibitorVertical
                anchors.horizontalCenter: parent.horizontalCenter
            }

            KeyboardLayoutIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Loader {
                active: DetectEnv.isLaptopBattery
                sourceComponent: BatteryIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
            Loader {
                active: DetectEnv.isNiri
                sourceComponent: NiriWorkspaces {
                    id: niriWorkspacesVertical
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Loader {
                active: DetectEnv.isHyprland
                sourceComponent: SpecialWorkspaces {
                    id: specialWorkspacesVertical
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Loader {
                active: DetectEnv.isHyprland
                sourceComponent: NormalWorkspaces {
                    id: normalWorkspacesVertical
                    anchors.horizontalCenter: parent.horizontalCenter
                    expanded: layoutLoader.normalWorkspacesExpanded
                    onExpandedChanged: layoutLoader.normalWorkspacesExpanded = expanded
                }
            }
        }
    }
}
