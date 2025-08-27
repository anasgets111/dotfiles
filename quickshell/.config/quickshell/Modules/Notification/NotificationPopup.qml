pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import qs.Services.SystemInfo
import QtQuick.Window

PanelWindow {
    id: layer
    visible: NotificationService.visible.length > 0
    required property var modelData
    screen: layer.modelData
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    mask: Region {
        item: popupScroll
    }
    property int margin: 12
    property int barOffset: 36
    // property int shadowPad: 16
    // Scrollable stack to avoid growing off-screen; still stacks vertically
    ScrollView {
        id: popupScroll
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.topMargin: layer.margin + layer.barOffset
        anchors.rightMargin: layer.margin
        anchors.bottomMargin: layer.margin
        clip: true
        // Size viewport to content width
        width: popupColumn.implicitWidth
        contentWidth: popupColumn.implicitWidth
        contentHeight: popupColumn.implicitHeight

        Column {
            id: popupColumn
            // local handle to the service to avoid unqualified access inside delegates
            readonly property var svc: NotificationService
            // Build entries from currently visible wrappers, honoring svc.maxVisible.
            // Coalesce by group so you get at most one entry per group id.
            property var entries: (function () {
                    const svc = popupColumn.svc;
                    const max = Math.max(1, Number(svc?.maxVisible || 1));
                    const result = [];
                    const seenGroups = new Set();
                    const vis = svc?.visible || [];
                    // Iterate visible wrappers in order, collect up to 'max' distinct entries
                    for (let i = 0; i < vis.length && result.length < max; ++i) {
                        const w = vis[i];
                        if (!w)
                            continue;
                        const gid = String(w.groupId || "");
                        if (gid) {
                            if (seenGroups.has(gid))
                                continue;
                            const g = (svc?.groupsMap && svc.groupsMap[gid]) || null;
                            if (g) {
                                result.push({
                                    kind: "group",
                                    group: g
                                });
                                seenGroups.add(gid);
                            } else {
                                result.push({
                                    kind: "single",
                                    wrapper: w
                                });
                            }
                        } else {
                            result.push({
                                kind: "single",
                                wrapper: w
                            });
                        }
                    }
                    // If grouping compressed entries below max, try to fill from the rest
                    for (let i = 0; i < vis.length && result.length < max; ++i) {
                        const w = vis[i];
                        if (!w)
                            continue;
                        const gid = String(w.groupId || "");
                        if (gid) {
                            if (!seenGroups.has(gid)) {
                                const g = (svc?.groupsMap && svc.groupsMap[gid]) || null;
                                if (g) {
                                    result.push({
                                        kind: "group",
                                        group: g
                                    });
                                    seenGroups.add(gid);
                                }
                            }
                        } else {
                            // ensure we don't duplicate singles already included
                            if (!result.some(e => e.kind === "single" && e.wrapper === w))
                                result.push({
                                    kind: "single",
                                    wrapper: w
                                });
                        }
                    }
                    return result;
                })()
            spacing: 8
            Repeater {
                model: popupColumn.entries
                delegate: Item {
                    id: del
                    required property var modelData
                    width: col.width
                    implicitWidth: col.implicitWidth
                    implicitHeight: col.implicitHeight
                    Column {
                        id: col
                        // Only create cards when inputs are present to avoid undefined access
                        Loader {
                            active: del.modelData.kind === "single" && !!del.modelData.wrapper
                            sourceComponent: NotificationCard {
                                wrapper: del.modelData.wrapper
                                onDismiss: popupColumn.svc.dismissNotification(wrapper)
                                onActionTriggered: id => popupColumn.svc.executeAction(wrapper.id, id)
                                onReplySubmitted: text => {
                                    const r = popupColumn.svc.reply(wrapper.id, text);
                                    if (r?.ok)
                                        wrapper.popup = false;
                                }
                            }
                        }
                        Loader {
                            active: del.modelData.kind === "group" && !!del.modelData.group
                            sourceComponent: GroupCard {
                                svc: popupColumn.svc
                                group: del.modelData.group
                            }
                        }
                    }
                }
            }
        }
    }
    Rectangle {
        id: dndBanner
        visible: NotificationService.dndPolicy?.enabled
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        radius: 6
        color: Qt.rgba(0.95, 0.55, 0.10, 0.9)
        width: txt.implicitWidth + 24
        height: 28
        Text {
            id: txt
            anchors.centerIn: parent
            color: "black"
            text: "Do Not Disturb: " + (NotificationService.dndPolicy?.behavior === "suppress" ? "Suppress" : "Queue")
        }
    }
}
