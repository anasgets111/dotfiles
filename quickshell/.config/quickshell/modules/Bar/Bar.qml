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

    // Window/layershell state debug (only supported signals/properties)
    onScreenChanged: console.log("[Bar] panelWindow.screen changed ->", panelWindow.screen ? panelWindow.screen.name : "<none>")
    onVisibleChanged: console.log("[Bar] visible:", panelWindow.visible)
    onWidthChanged: console.log("[Bar] width:", panelWindow.width)
    onHeightChanged: console.log("[Bar] height:", panelWindow.height)

    // Note: WlrLayershell may not expose mapped; log available props
    onColorChanged: console.log("[Bar] color changed")

    // React to screen topology changes (plug/unplug/wake) with debounce
    Item {
        id: screenBinder
        property int debounceRestarts: 0

        // Debounce timer to handle brief flapping during wake/connect
        Timer {
            id: screenDebounce
            interval: 500
            repeat: false
            onTriggered: {
                console.log("[Bar] Debounce triggered. Re-evaluating screen...")
                const sel = screenBinder.pickScreen()
                console.log("[Bar] Assigning panelWindow.screen to:", sel ? `${sel.name} ${sel.width}x${sel.height}` : "<none>")
                panelWindow.screen = sel
                postAssignCheck.restart()
            }
        }

        // short post-assign check to see visibility
        Timer {
            id: postAssignCheck
            interval: 80
            repeat: false
            onTriggered: console.log("[Bar] post-assign visible:", panelWindow.visible, "ns:", WlrLayershell.namespace)
        }

        function logScreensDetail(prefix) {
            const count = Quickshell.screens.length
            console.log(`${prefix} screens length= ${count}`)
            Quickshell.screens.forEach((s, i) => console.log(`[Bar]  - [${i}] name=${s.name} size=${s.width}x${s.height} enabled=${s.enabled} primary=${s.primary}`))
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
            screenBinder.logScreensDetail("[Bar] initial")
            panelWindow.screen = screenBinder.pickScreen()
            console.log("[Bar] namespace:", WlrLayershell.namespace)
        }

        Connections {
            target: Quickshell
            // Fired when outputs list or their availability changes
            function onScreensChanged() {
                screenBinder.logScreensDetail("[Bar] onScreensChanged():")
                screenBinder.debounceRestarts += 1
                console.log(`[Bar] restarting debounce #${screenBinder.debounceRestarts} (${screenDebounce.interval}ms)`)            
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
