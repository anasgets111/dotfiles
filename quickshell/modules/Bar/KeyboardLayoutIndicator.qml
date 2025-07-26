import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitHeight: Theme.itemHeight
    implicitWidth: Math.max(Theme.itemWidth, label.implicitWidth + 12)

    property alias kbService: serviceLoader.item

    Loader {
        id: serviceLoader
        source: "KbService.qml"
        onLoaded: {
            if (kbService && kbService.seedInitial)
                kbService.seedInitial()
        }
    }

    visible: kbService && kbService.available

    Rectangle {
        anchors.fill: parent
        radius: Theme.itemRadius
        color: Theme.inactiveColor
        implicitWidth: Math.max(Theme.itemWidth, label.implicitWidth + 12)

        RowLayout {
            anchors.fill: parent

            Text {
                id: label
                text: kbService ? kbService.shortName(kbService.currentLayout) : ""
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                font.bold: true
                color: Theme.textContrast(Theme.inactiveColor)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            }
        }
    }
}
