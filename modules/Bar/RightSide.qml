import QtQuick


Row {
    id: rightSide
    spacing: 8

    // Styling properties are now accessed from Theme singleton

    // Placeholder content for right section
    Text {
        text: "Right"
        color: Theme.textInactiveColor
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        anchors.verticalCenter: parent.verticalCenter
    }
}
