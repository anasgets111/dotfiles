import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panelWindow

    property bool normalWorkspacesExpanded: false

    implicitWidth: panelWindow.screen.width
    implicitHeight: panelWindow.screen.height
    exclusiveZone: Theme.panelHeight
    // Use dynamic screen selection: prefer second screen when present
    screen: screenBinder.pickScreen()
    WlrLayershell.namespace: "quickshell:bar"
    color: Theme.panelWindowColor

    // React to screen topology changes (plug/unplug/wake) with debounce
    Item {
        id: screenBinder

        // Debounce timer to handle brief flapping during wake/connect
        Timer {
            id: screenDebounce
            interval: 2000
            repeat: false
            onTriggered: {
                console.log("[Bar] Debounce triggered. Re-evaluating screen...")
                const sel = screenBinder.pickScreen()
                console.log("[Bar] Assigning panelWindow.screen to:", sel ? sel.name : "<none>")
                panelWindow.screen = sel
            }
        }

        function pickScreen() {
            const count = Quickshell.screens.length
            const names = Quickshell.screens.map(s => s.name).join(", ")
            console.log(`[Bar] pickScreen() called. screens length= ${count} [${names}]`)
            // Prefer second screen (index 1) if present, else first (index 0)
            if (count > 1) {
                console.log("[Bar] Choosing screens[1] ->", Quickshell.screens[1].name)
                return Quickshell.screens[1]
            }
            if (count > 0) {
                console.log("[Bar] Falling back to screens[0] ->", Quickshell.screens[0].name)
                return Quickshell.screens[0]
            }
            console.warn("[Bar] No screens available. Returning null.")
            return null
        }

        Component.onCompleted: {
            console.log("[Bar] screenBinder ready. Initial screen selection...")
            panelWindow.screen = pickScreen()
        }

        Connections {
            target: Quickshell
            // Fired when outputs list or their availability changes
            function onScreensChanged() {
                const count = Quickshell.screens.length
                const names = Quickshell.screens.map(s => s.name).join(", ")
                console.log(`[Bar] onScreensChanged(): screens length= ${count} [${names}] -> restarting debounce (${screenDebounce.interval}ms)`)            
                screenDebounce.restart()
            }
        }
    }

    anchors {
        top: true
        left: true
        right: true
    }

    Rectangle {
        id: panelRect

        width: parent.width
        height: Theme.panelHeight
        color: Theme.bgColor
        anchors.top: parent.top
        anchors.left: parent.left
    }

    LeftSide {
        normalWorkspacesExpanded: panelWindow.normalWorkspacesExpanded
        onNormalWorkspacesExpandedChanged: panelWindow.normalWorkspacesExpanded = normalWorkspacesExpanded

        anchors {
            left: panelRect.left
            leftMargin: Theme.panelMargin
            verticalCenter: panelRect.verticalCenter
        }
    }

    CenterSide {
        anchors.centerIn: panelRect
        normalWorkspacesExpanded: panelWindow.normalWorkspacesExpanded
    }

    RightSide {
        anchors {
            right: panelRect.right
            rightMargin: Theme.panelMargin
            verticalCenter: panelRect.verticalCenter
        }
    }

    Item {
        id: bottomCuts

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

    mask: Region {
        item: panelRect
    }
}
