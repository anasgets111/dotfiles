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
            id: centerSide
            spacing: 8

            ActiveWindow {
                id: activeWindowTitle
                anchors.verticalCenter: parent.verticalCenter
                opacity: layoutLoader.normalWorkspacesExpanded ? 0 : 1
                visible: true
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    Component {
        id: columnLayout
        Column {
            id: centerSideVertical
            spacing: 8

            ActiveWindow {
                id: activeWindowTitleVertical
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: layoutLoader.normalWorkspacesExpanded ? 0 : 1
                visible: true
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }
}
