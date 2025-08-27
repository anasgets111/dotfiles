pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services.SystemInfo

Control {
    id: groupCard
    required property var group      // { id, title, children, expanded, updatedAt, appName }
    // Provide access to service
    property var svc: NotificationService

    // Resolve wrappers from svc.all matching group.id
    readonly property var items: {
        const out = [];
        const ids = (groupCard.group?.children || []);
        const all = (groupCard.svc?.all || []);
        for (let i = 0; i < all.length; ++i) {
            const w = all[i];
            if (!w)
                continue;
            if (String(w.groupId || "") !== String(groupCard.group?.id || ""))
                continue;
            out.push(w);
        }
        // keep order by arrival or group.children order
        // children is newest-first by your _touchGroup; mirror that:
        out.sort((a, b) => ids.indexOf(String(a.id)) - ids.indexOf(String(b.id)));
        return out;
    }

    readonly property var latest: (items && items.length) ? items[0] : null
    implicitWidth: 380
    padding: 10

    background: Rectangle {
        radius: 8
        color: "#282828"
        border.color: "#2a2a2a"
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 8

        // Header row: title, app, count, expand/collapse
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: ((groupCard.group && groupCard.group.title) || "(Group)") + " — " + ((groupCard.group && groupCard.group.appName) || "")
                color: "white"
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Rectangle {
                radius: 10
                color: "#3a3a3a"
                implicitHeight: 20
                implicitWidth: Math.max(20, countText.implicitWidth + 10)
                Layout.preferredWidth: implicitWidth
                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: String(groupCard.items.length)
                    color: "white"
                    font.pixelSize: 11
                }
            }
            ToolButton {
                visible: !!groupCard.group
                text: groupCard.group && groupCard.group.expanded ? "Collapse" : "Expand"
                onClicked: {
                    if (!groupCard.group)
                        return;
                    // Optimistic local toggle so UI updates immediately
                    groupCard.group.expanded = !groupCard.group.expanded;
                    if (groupCard.svc)
                        groupCard.svc.toggleGroup(groupCard.group.id, groupCard.group.expanded);
                }
            }
        }

        // Collapsed: preview latest
        Item {
            visible: !!groupCard.group && !groupCard.group.expanded && !!groupCard.latest
            implicitHeight: previewCard.implicitHeight
            implicitWidth: previewCard.implicitWidth
            NotificationCard {
                id: previewCard
                wrapper: groupCard.latest
                onDismiss: groupCard.svc.dismissNotification(wrapper)
                onActionTriggered: id => groupCard.svc.executeAction(wrapper.id, id)
                onReplySubmitted: text => {
                    const r = groupCard.svc.reply(wrapper.id, text);
                    if (r?.ok)
                        wrapper.popup = false;
                }
            }
        }

        // Expanded: list all items
        ColumnLayout {
            visible: !!groupCard.group && groupCard.group.expanded
            spacing: 6
            Repeater {
                model: groupCard.items
                delegate: NotificationCard {
                    required property var modelData
                    wrapper: modelData
                    onDismiss: groupCard.svc.dismissNotification(modelData)
                    onActionTriggered: id => groupCard.svc.executeAction(modelData.id, id)
                    onReplySubmitted: text => {
                        const r = groupCard.svc.reply(modelData.id, text);
                        if (r?.ok)
                            modelData.popup = false;
                    }
                }
            }
        }
    }
}
