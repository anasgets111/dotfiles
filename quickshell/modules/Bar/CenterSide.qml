import QtQuick


Row {
    id: centerSide
    spacing: 8

    // Active window title display
    ActiveWindow {
        id: activeWindowTitle
        anchors.verticalCenter: parent.verticalCenter
    }
}
