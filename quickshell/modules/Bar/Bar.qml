import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panelWindow
    property bool normalWorkspacesExpanded: false
    property bool verticalMode: false
    mask: Region {
        item: panelRect
    }
    implicitWidth: verticalMode ? Theme.panelHeight : Screen.width
    implicitHeight: verticalMode ? Screen.height : Theme.panelHeight + Theme.panelRadius + Theme.tooltipMaxSpace
    exclusiveZone: verticalMode ? Theme.panelHeight : Theme.panelHeight

    screen: Quickshell.screens.length > 1 ? Quickshell.screens[1] : Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:bar:blur"
    anchors {
        top: verticalMode ? true : true
        left: true
        right: verticalMode ? false : true
        bottom: verticalMode ? true : false
    }
    color: Theme.panelWindowColor

    Rectangle {
        id: panelRect
        width: verticalMode ? Theme.panelHeight : parent.width
        height: verticalMode ? parent.height : Theme.panelHeight
        color: Theme.bgColor
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.bottom: verticalMode ? parent.bottom : undefined
        anchors.right: verticalMode ? undefined : parent.right
    }

    LeftSide {
        anchors {
            left: panelRect.left
            leftMargin: Theme.panelMargin
            verticalCenter: !panelWindow.verticalMode ? panelRect.verticalCenter : undefined
            top: panelWindow.verticalMode ? panelRect.top : undefined
            horizontalCenter: panelWindow.verticalMode ? panelRect.horizontalCenter : undefined
        }
        normalWorkspacesExpanded: panelWindow.normalWorkspacesExpanded
        onNormalWorkspacesExpandedChanged: panelWindow.normalWorkspacesExpanded = normalWorkspacesExpanded
        verticalMode: panelWindow.verticalMode
    }
    CenterSide {
        anchors.centerIn: panelRect
        normalWorkspacesExpanded: panelWindow.normalWorkspacesExpanded
        verticalMode: panelWindow.verticalMode
    }
    RightSide {
        anchors {
            right: panelRect.right
            rightMargin: Theme.panelMargin
            verticalCenter: !panelWindow.verticalMode ? panelRect.verticalCenter : undefined
            bottom: panelWindow.verticalMode ? panelRect.bottom : undefined
            horizontalCenter: panelWindow.verticalMode ? panelRect.horizontalCenter : undefined
        }
        verticalMode: panelWindow.verticalMode
    }

    // Horizontal bottom cuts
    Item {
        id: bottomCuts
        visible: !verticalMode
        width: parent.width
        height: Theme.panelRadius
        anchors.top: panelRect.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        RoundCorner {
            anchors.left: parent.left
            anchors.top: parent.top
            size: Theme.panelRadius
            color: Theme.bgColor
            corner: 2
            rotation: 90
        }

        RoundCorner {
            anchors.right: parent.right
            anchors.top: parent.top
            size: Theme.panelRadius
            color: Theme.bgColor
            corner: 3
            rotation: -90
        }
    }

    // Vertical left cuts
    Item {
        id: verticalCuts
        visible: verticalMode
        width: Theme.panelRadius
        height: parent.height
        anchors.left: panelRect.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        RoundCorner {
            anchors.top: parent.top
            anchors.left: parent.left
            size: Theme.panelRadius
            color: Theme.bgColor
            corner: 1
            rotation: 0
        }

        RoundCorner {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            size: Theme.panelRadius
            color: Theme.bgColor
            corner: 4
            rotation: 180
        }
    }
}
