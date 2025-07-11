import QtQuick
// import "DateTimeDisplay.qml"


Row {
    id: rightSide
    spacing: 8

    // Styling properties are now accessed from Theme singleton

    // DateTimeDisplay module
    DateTimeDisplay {
        anchors.verticalCenter: parent.verticalCenter
    }

    // PowerMenu integration
    PowerMenu {
        anchors.verticalCenter: parent.verticalCenter
    }
}
