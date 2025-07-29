import QtQuick

Row {
    id: centerSide

    property bool normalWorkspacesExpanded: false

    spacing: 8

    // Active window title display
    ActiveWindow {
        id: activeWindowTitle

        anchors.verticalCenter: parent.verticalCenter
        opacity: normalWorkspacesExpanded ? 0 : 1
        visible: true

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animationDuration
                easing.type: Easing.InOutQuad
            }
        }
    }
}
