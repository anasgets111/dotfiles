import QtQuick

Loader {
    id: layoutLoader
    active: true
    sourceComponent: verticalMode ? columnLayout : rowLayout
    property bool verticalMode: false

    Component {
        id: rowLayout
        Row {
            id: rightSide
            spacing: 8

            Volume {
                anchors.verticalCenter: parent.verticalCenter
            }
            // RecordingStatus {
            //     anchors.verticalCenter: parent.verticalCenter
            // }
            SysTray {
                anchors.verticalCenter: parent.verticalCenter
                bar: panelWindow
            }

            DateTimeDisplay {
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Component {
        id: columnLayout
        Column {
            id: rightSideVertical
            spacing: 8

            Volume {
                anchors.horizontalCenter: parent.horizontalCenter
            }
            // RecordingStatus {
            //     anchors.horizontalCenter: parent.horizontalCenter
            // }
            SysTray {
                anchors.horizontalCenter: parent.horizontalCenter
                bar: panelWindow
            }

            DateTimeDisplay {
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
