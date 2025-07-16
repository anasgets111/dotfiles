import QtQuick
// import "DateTimeDisplay.qml"


Row {
    id: rightSide
    spacing: 8

    // Volume control
    Volume {
        anchors.verticalCenter: parent.verticalCenter
    }

    // DateTimeDisplay module
    DateTimeDisplay {
        anchors.verticalCenter: parent.verticalCenter
    }

    // PowerMenu integration
    PowerMenu {
        anchors.verticalCenter: parent.verticalCenter
    }
}
