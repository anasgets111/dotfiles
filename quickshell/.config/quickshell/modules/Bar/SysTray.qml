pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

Item {
    id: systemTrayWidget

    required property var bar
    readonly property int iconSpacing: 8
    readonly property int horizontalPadding: 10
    readonly property int hoverPadding: 3
    readonly property int contentInset: 2

    // (removed helper; using direct heuristic lookup in delegate)

    width: Math.max(trayRow.implicitWidth + horizontalPadding * 2, Theme.itemHeight)
    height: Theme.itemHeight

    Rectangle {
        id: pillContainer

        anchors.fill: parent
        radius: Theme.itemRadius
        color: Theme.inactiveColor
    }

    Row {
        id: trayRow

        anchors.centerIn: parent
        spacing: systemTrayWidget.iconSpacing
        Repeater {
            id: trayRepeater
            model: SystemTray.items
            delegate: trayItemDelegate
        }
    }

    Component {
        id: trayItemDelegate

        MouseArea {
            id: trayMouseArea

            required property var modelData
            property var trayItem: modelData
            // local computed properties to reduce duplication and improve readability
            property string itemIcon: trayItem.icon
            property var lastIpc: modelData && modelData.lastIpcObject ? modelData.lastIpcObject : null
            property var heuristic: lastIpc ? DesktopEntries.heuristicLookup(lastIpc.class) : null

            width: Theme.iconSize
            height: Theme.iconSize
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            hoverEnabled: true

            onClicked: function (mouse) {
                if (mouse.button === Qt.LeftButton)
                    trayMouseArea.trayItem.activate();
                else if (mouse.button === Qt.RightButton && trayMouseArea.trayItem.hasMenu)
                    menuAnchor.open();
                else if (mouse.button === Qt.MiddleButton)
                    trayMouseArea.trayItem.secondaryActivate();
            }
            onWheel: function (wheel) {
                trayMouseArea.trayItem.scroll(wheel.angleDelta.x, wheel.angleDelta.y);
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayMouseArea.trayItem.menu
                anchor.item: trayMouseArea
                anchor.rect.x: 0
                anchor.rect.y: trayMouseArea.height - 5
            }

            Rectangle {
                anchors.centerIn: parent
                width: Theme.iconSize + systemTrayWidget.hoverPadding * 2
                height: width
                radius: width / 2
                color: Theme.onHoverColor
                opacity: trayMouseArea.containsMouse ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            IconImage {
                id: iconImage

                anchors.centerIn: parent
                implicitSize: Theme.iconSize - systemTrayWidget.contentInset * 2
                width: implicitSize
                height: implicitSize
                source: trayMouseArea.itemIcon.startsWith("image://") ? trayMouseArea.itemIcon : (trayMouseArea.heuristic && trayMouseArea.heuristic.icon ? Quickshell.iconPath(trayMouseArea.heuristic.icon) : "")
                backer.smooth: true
                backer.fillMode: Image.PreserveAspectFit
                backer.sourceSize.width: width
                backer.sourceSize.height: height
                visible: status !== Image.Error && status !== Image.Null && source !== ""
            }

            Text {
                anchors.centerIn: parent
                text: trayMouseArea.trayItem.tooltipTitle ? trayMouseArea.trayItem.tooltipTitle : (trayMouseArea.trayItem.title ? trayMouseArea.trayItem.title.charAt(0).toUpperCase() : "?")
                color: trayMouseArea.containsMouse ? Theme.textOnHoverColor : Theme.textActiveColor
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                font.bold: true
                visible: iconImage.status === Image.Error || iconImage.status === Image.Null || iconImage.source === ""
            }

            Rectangle {
                id: tooltip

                visible: trayMouseArea.containsMouse && (trayMouseArea.trayItem.tooltipTitle || trayMouseArea.trayItem.title)
                color: Theme.onHoverColor
                radius: Theme.itemRadius
                width: tooltipText.width + 16
                height: tooltipText.height + 8
                anchors.top: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 8
                opacity: trayMouseArea.containsMouse ? 1 : 0

                Text {
                    id: tooltipText

                    anchors.centerIn: parent
                    text: trayMouseArea.trayItem.tooltipTitle ? trayMouseArea.trayItem.tooltipTitle : trayMouseArea.trayItem.title
                    color: Theme.textContrast(trayMouseArea.containsMouse ? Theme.onHoverColor : Theme.inactiveColor)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: trayRepeater.count === 0
        text: "No tray items"
        color: Theme.panelColor
        font.pixelSize: 10
        font.family: Theme.fontFamily
        opacity: 0.7
    }
}
