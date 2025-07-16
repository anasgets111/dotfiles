import QtQuick
// import "DateTimeDisplay.qml"


Row {
    id: rightSide
    spacing: 8

    KeyboardLayoutIndicator{
        anchors.verticalCenter: parent.verticalCenter
    }

    BatteryIndicator {
        anchors.verticalCenter: parent.verticalCenter
    }

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
