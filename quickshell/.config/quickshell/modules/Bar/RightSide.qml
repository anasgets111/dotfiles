import QtQuick

Row {
    id: rightSide

    spacing: 8

    Volume {
        anchors.verticalCenter: parent.verticalCenter
    }

    RecordingStatus {
        anchors.verticalCenter: parent.verticalCenter
    }

    SysTray {
        anchors.verticalCenter: parent.verticalCenter
        bar: panelWindow
    }

    DateTimeDisplay {
        anchors.verticalCenter: parent.verticalCenter
    }
}
