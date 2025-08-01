// pragma ComponentBehavior: Bound
//@ pragma IconTheme Tela-circle-dracula-dark

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Item {
    id: systemTrayWidget

    required property var bar
    readonly property int iconSpacing: 8
    property var fallbackOrder: []
    property var availableThemes: []
    property string preferredIconTheme: Quickshell.env("ICON_THEME") || (availableThemes.length > 0 ? availableThemes[0] : "hicolor")
    readonly property var iconDirs: ["scalable/apps/", "scalable/actions/", "scalable/devices/", "scalable/status/", "scalable/places/", "48x48/apps/", "48x48/actions/", "48x48/devices/", "48x48/status/", "48x48/places/"]
    readonly property var iconExts: [".svg", ".png"]

    function getThemeIconName(iconUrl) {
        var m = iconUrl.match(/image:\/\/(?:icon|qspixmap)\/([^\/]+)/);
        return m ? m[1] : iconUrl;
    }

    function getIconPath(iconName) {
        for (var i = 0; i < iconDirs.length; i++) {
            for (var j = 0; j < iconExts.length; j++) {
                var candidate = iconDirs[i] + iconName + iconExts[j];
                // Quickshell.iconPath allows theme override via QS_ICON_THEME env
                var path = Quickshell.iconPath(candidate, true);
                if (path)
                    return path;
            }
        }
        return Quickshell.iconPath("image-missing", true);
    }

    width: trayRow.width + iconSpacing
    height: Theme.itemHeight
    Component.onCompleted: {
        availableThemes = fallbackOrder;
    }

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

            MouseArea {
                id: trayMouseArea

                property var trayItem: modelData

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
                    anchor.window: systemTrayWidget.bar
                    anchor.item: iconImage
                }

                Rectangle {
                    width: Theme.iconSize + 6
                    height: Theme.iconSize + 6
                    anchors.centerIn: parent
                    radius: (Theme.iconSize + 6) / 2
                    color: trayMouseArea.containsMouse ? Theme.onHoverColor : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animationDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Image {
                    id: iconImage

                    property string iconName: systemTrayWidget.getThemeIconName(trayMouseArea.trayItem.icon)
                    property string themePath: systemTrayWidget.getIconPath(iconName)

                    anchors.centerIn: parent
                    width: Theme.iconSize
                    height: Theme.iconSize
                    source: trayMouseArea.trayItem.icon.startsWith("image://") ? trayMouseArea.trayItem.icon : themePath
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: status !== Image.Error && status !== Image.Null
                    onStatusChanged: {
                        if (status === Image.Error && trayMouseArea.trayItem.icon.startsWith("image://")) {
                            var fp = systemTrayWidget.getIconPath(iconName);
                            if (fp)
                                source = fp;
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: trayMouseArea.trayItem.tooltipTitle ? trayMouseArea.trayItem.tooltipTitle : (trayMouseArea.trayItem.title ? trayMouseArea.trayItem.title.charAt(0).toUpperCase() : "?")
                    color: trayMouseArea.containsMouse ? Theme.textOnHoverColor : Theme.textActiveColor
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                    font.bold: true
                    visible: iconImage.status === Image.Error || iconImage.status === Image.Null
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
