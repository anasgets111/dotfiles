import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panelWindow

    property bool normalWorkspacesExpanded: false

    implicitWidth: panelWindow.screen.width
    implicitHeight: panelWindow.screen.height
    exclusiveZone: Theme.panelHeight
    // Use dynamic screen selection based on preferred outputs, with fallback
    screen: screenBinder.pickScreen()
    WlrLayershell.namespace: "quickshell:bar:blur"
    // Use enum for layer
    WlrLayershell.layer: WlrLayer.Top
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
        // preferred output names in priority order
        property var preferred: ["DP-3", "HDMI-A-1"]

        // Debounce timer to handle brief flapping during wake/connect
        Timer {
            id: screenDebounce
            interval: 500
            repeat: false
            onTriggered: {
                console.log("[Bar] Debounce triggered. Re-evaluating screen...")
                const sel = screenBinder.pickScreen()
                console.log("[Bar] Candidate screen:", sel ? `${sel.name} ${sel.width}x${sel.height}` : "<none>")
                if (sel && panelWindow.screen === sel) {
                    console.log("[Bar] Skipping reassign; screen unchanged")
                } else {
                    console.log("[Bar] Assigning panelWindow.screen")
                    panelWindow.screen = sel
                }
                postAssignCheck.restart()
            }
        }

        // short post-assign check to see visibility and sizes
        Timer {
            id: postAssignCheck
            interval: 160
            repeat: false
            onTriggered: {
                const scr = panelWindow.screen
                console.log("[Bar] post-assign:",
                    "visible=", panelWindow.visible,
                    "scr=", scr ? `${scr.name} ${scr.width}x${scr.height}` : "<none>",
                    "implicit=", panelWindow.implicitWidth + "x" + panelWindow.implicitHeight,
                    "panelRect=", panelRect.width + "x" + panelRect.height,
                    "exclusiveZone=", Theme.panelHeight,
                    "namespace=", WlrLayershell.namespace,
                    "layer=", WlrLayershell.layer)
                if (!panelWindow.visible && scr) {
                    console.log("[Bar] Panel not visible after assign; scheduling remap")
                    remapIfHidden.start()
                }
            }
        }

        // try to remap if compositor left us hidden after topology change
        Timer {
            id: remapIfHidden
            interval: 350
            repeat: false
            onTriggered: {
                if (!panelWindow.visible && panelWindow.screen) {
                    console.log("[Bar] forcing remap: toggling visibility true")
                    panelWindow.visible = true
                }
            }
        }

        function logScreensDetail(prefix) {
            // Detailed list including zero-sized screens
            const count = Quickshell.screens.length
            console.log(`${prefix} screens length= ${count}`)
            Quickshell.screens.forEach((s, i) => console.log(`[Bar]  - [${i}] name=${s.name} size=${s.width}x${s.height} enabled=${s.enabled} primary=${s.primary}`))
        }

        function pickScreen() {
            // Filter out transient zero-sized screens to avoid mapping issues
            const valid = Quickshell.screens.filter(s => (s.width || 0) > 0 && (s.height || 0) > 0)
            const namesAll = Quickshell.screens.map(s => s.name).join(", ")
            const namesValid = valid.map(s => s.name).join(", ")
            console.log(`[Bar] pickScreen() called. all= [${namesAll}] valid(non-zero)= [${namesValid}] preferred= [${screenBinder.preferred.join(', ')}]`)

            // 1) Try preferred names (first present wins)
            for (let i = 0; i < screenBinder.preferred.length; i++) {
                const name = screenBinder.preferred[i]
                const match = valid.find(s => s.name === name)
                if (match) {
                    console.log("[Bar] Choosing preferred ->", match.name)
                    return match
                }
            }
            // 2) Fallback: second valid if exists, else first
            if (valid.length > 1) {
                console.log("[Bar] Choosing valid[1] ->", valid[1].name)
                return valid[1]
            }
            if (valid.length > 0) {
                console.log("[Bar] Falling back to valid[0] ->", valid[0].name)
                return valid[0]
            }
            console.warn("[Bar] No valid screens (non-zero) available. Returning null.")
            return null
        }

        Component.onCompleted: {
            console.log("[Bar] screenBinder ready. Initial screen selection...")
            screenBinder.logScreensDetail("[Bar] initial")
            // Do not force assign if binding already evaluates
            console.log("[Bar] namespace:", WlrLayershell.namespace, "layer:", WlrLayershell.layer)
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
