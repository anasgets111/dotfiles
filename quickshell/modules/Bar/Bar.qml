import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland


PanelWindow {
    id: panelWindow

    implicitWidth:  Screen.width
    implicitHeight: Theme.panelHeight + Theme.cornerRadius
    exclusiveZone:  Theme.panelHeight

    screen: Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:bar:blur"
    anchors { top: true; left: true; right: true }
    color:  Theme.panelWindowColor

    Rectangle {
        id: panelRect
        width:  parent.width
        height: Theme.panelHeight
        color:  Theme.bgColor
        anchors.top: parent.top
        anchors.left: parent.left
    }

    LeftSide {
        anchors {
            left:        panelRect.left
            leftMargin:  Theme.panelMargin
            verticalCenter: panelRect.verticalCenter
        }
    }
    CenterSide {
        anchors.centerIn: panelRect
    }
    RightSide {
        anchors {
            right:        panelRect.right
            rightMargin:  Theme.panelMargin
            verticalCenter: panelRect.verticalCenter
        }
    }

    Item {
        id: bottomCuts
        width:  parent.width
        height: Theme.cornerRadius
        anchors.top:    panelRect.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right

        RoundCorner {
            anchors.left: parent.left
            anchors.top: parent.top
            size: Theme.cornerRadius
            color: Theme.bgColor
            corner: 2
            rotation: 90
        }

        RoundCorner {
            anchors.right: parent.right
            anchors.top: parent.top
            size: Theme.cornerRadius
            color: Theme.bgColor
            corner: 3
            rotation: -90
        }
    }
}
