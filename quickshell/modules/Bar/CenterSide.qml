import QtQuick

Row {
    id: centerSide
    spacing: 8

    property bool normalWorkspacesExpanded: false

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
