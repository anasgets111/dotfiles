import QtQuick


Row {
    id: rightSide
    spacing: 8

    Volume {
        anchors.verticalCenter: parent.verticalCenter
    }

    UpdateChecker {
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
