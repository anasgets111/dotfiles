pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services.Utils
import qs.Config

Item {
  id: root

  required property var svc
  property var wrapper: null
  property var group: null

  signal inputFocusRequested

  readonly property bool isGroup: !!group
  readonly property var items: isGroup ? (group?.notifications || []) : (wrapper ? [wrapper] : [])
  readonly property var primaryWrapper: items.length > 0 ? items[0] : null
  readonly property bool groupExpanded: !isGroup || (svc?.expandedGroups ? (svc.expandedGroups[group.key] || false) : false)
  readonly property bool headerHasExpand: isGroup && items.length > 1
  readonly property string headerTitle: isGroup ? `${group?.appName || "app"} (${group?.count || items.length})` : (primaryWrapper?.appName || "app")
  readonly property color accentColor: primaryWrapper?.accentColor || Theme.activeColor

  readonly property real cardWidth: 380
  implicitWidth: cardWidth
  implicitHeight: frame.implicitHeight

  property var _messageExpansion: ({})
  function toggleMessageExpansion(id) {
    if (!id)
      return;
    const next = {};
    for (const key in root._messageExpansion)
      next[key] = root._messageExpansion[key];
    next[id] = !next[id];
    root._messageExpansion = next;
  }
  function messageExpanded(id) {
    return id ? !!root._messageExpansion[id] : false;
  }

  Keys.onEscapePressed: {
    if (root.isGroup)
      root.svc?.dismissGroup(root.group?.key);
    else if (root.primaryWrapper)
      root.svc?.dismissNotification(root.primaryWrapper);
  }

  property bool _animReady: false
  x: !_animReady ? width + (Theme.popupOffset || 12) : 0
  Behavior on x {
    NumberAnimation {
      duration: (Theme.animationDuration || 200) * 1.4
      easing.type: Easing.OutCubic
    }
  }
  Component.onCompleted: Qt.callLater(() => _animReady = true)

  Item {
    id: frame
    width: root.cardWidth
    implicitHeight: cardColumn.implicitHeight + 24

    CardStyling {
      anchors.fill: parent
      accentColor: root.accentColor
    }

    ColumnLayout {
      id: cardColumn
      anchors.fill: parent
      anchors.margins: 12
      spacing: 10

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Loader {
          Layout.preferredWidth: active ? 40 : 0
          Layout.preferredHeight: active ? 40 : 0
          active: !!root.primaryWrapper
          sourceComponent: Rectangle {
            width: 40
            height: 40
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.05)
            Image {
              anchors.centerIn: parent
              width: 30
              height: 30
              fillMode: Image.PreserveAspectFit
              smooth: true
              source: Utils.resolveIconSource(root.primaryWrapper?.appName || "app", root.primaryWrapper?.appIcon, "dialog-information")
              sourceSize: Qt.size(64, 64)
              onStatusChanged: if (status === Image.Error)
                parent.parent.active = false
            }
          }
        }

        Text {
          Layout.fillWidth: true
          text: root.headerTitle
          color: "white"
          font.bold: true
          font.pixelSize: 15
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }

        RowLayout {
          spacing: 6

          Loader {
            active: root.headerHasExpand
            sourceComponent: StandardButton {
              buttonType: "control"
              text: root.groupExpanded ? "▴" : "▾"
              Accessible.name: root.groupExpanded ? "Collapse group" : "Expand group"
              onClicked: root.svc?.toggleGroupExpansion(root.group?.key)
            }
          }

          StandardButton {
            buttonType: "control"
            text: "×"
            Accessible.name: root.isGroup ? "Dismiss group" : "Dismiss notification"
            onClicked: {
              if (root.isGroup)
                root.svc?.dismissGroup(root.group?.key);
              else if (root.primaryWrapper)
                root.svc?.dismissNotification(root.primaryWrapper);
            }
          }
        }
      }

      ColumnLayout {
        id: cardContent
        Layout.fillWidth: true
        spacing: 12
        readonly property var renderedItems: root.isGroup && !root.groupExpanded ? (root.items.length > 0 ? [root.items[0]] : []) : root.items

        Repeater {
          model: cardContent.renderedItems
          delegate: ColumnLayout {
            id: messageColumn
            required property var modelData
            readonly property string summary: modelData?.summary || "(No title)"
            readonly property string body: modelData?.body || ""
            readonly property string messageId: modelData?.id || String(modelData?.notification ? modelData.notification.id || "" : "")
            readonly property url contentImage: modelData?.cleanImage || ""
            readonly property bool hasBody: modelData?.hasBody === true ? true : (body && body.trim() !== "" && body.trim() !== summary.trim())
            readonly property bool expanded: root.messageExpanded(messageColumn.messageId)
            readonly property bool hasInlineReply: modelData?.hasInlineReply === true
            readonly property string inlineReplyPlaceholder: modelData?.inlineReplyPlaceholder || "Reply"
            readonly property var actionsModel: modelData?.actions || []
            property bool summaryTruncated: false
            property bool bodyTruncated: false

            Layout.fillWidth: true
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Loader {
                Layout.preferredWidth: active ? 24 : 0
                Layout.preferredHeight: active ? 24 : 0
                active: !!messageColumn.contentImage
                sourceComponent: Image {
                  width: 24
                  height: 24
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                  source: messageColumn.contentImage
                  onStatusChanged: if (status === Image.Error)
                    parent.parent.active = false
                }
              }

              Text {
                id: summaryText
                Layout.fillWidth: true
                text: messageColumn.summary
                color: "#dddddd"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: messageColumn.expanded ? 0 : 2
                Component.onCompleted: messageColumn.summaryTruncated = truncated
                onTruncatedChanged: messageColumn.summaryTruncated = truncated
              }

              Loader {
                active: messageColumn.summaryTruncated || messageColumn.bodyTruncated || messageColumn.expanded
                sourceComponent: StandardButton {
                  buttonType: "control"
                  text: messageColumn.expanded ? "▴" : "▾"
                  Accessible.name: messageColumn.expanded ? "Collapse message" : "Expand message"
                  onClicked: root.toggleMessageExpansion(messageColumn.messageId)
                }
              }
            }

            Loader {
              id: bodyLoader
              Layout.fillWidth: true
              active: messageColumn.hasBody
              onActiveChanged: if (!active)
                messageColumn.bodyTruncated = false
              sourceComponent: Text {
                id: bodyText
                Layout.fillWidth: true
                color: "#bbbbbb"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                text: messageColumn.body
                maximumLineCount: messageColumn.expanded ? 0 : 2
                elide: Text.ElideRight
                Component.onCompleted: messageColumn.bodyTruncated = truncated
                onTruncatedChanged: messageColumn.bodyTruncated = truncated
                onLinkActivated: url => Qt.openUrlExternally(url)
              }
            }

            Loader {
              Layout.fillWidth: true
              active: messageColumn.hasInlineReply
              sourceComponent: RowLayout {
                Layout.fillWidth: true
                spacing: 6

                TextField {
                  id: replyField
                  Layout.fillWidth: true
                  placeholderText: messageColumn.inlineReplyPlaceholder
                  selectByMouse: true
                  activeFocusOnPress: true
                  font.pixelSize: 13
                  padding: 6
                  Keys.onReturnPressed: sendBtn.clicked()
                  Keys.onEnterPressed: sendBtn.clicked()
                  onActiveFocusChanged: if (activeFocus)
                    root.inputFocusRequested()
                  background: Rectangle {
                    anchors.fill: parent
                    radius: Theme.itemRadius
                    color: Theme.bgColor
                    border.width: 1
                    border.color: replyField.activeFocus ? Theme.activeColor : Theme.borderColor
                  }
                }

                StandardButton {
                  id: sendBtn
                  buttonType: "action"
                  text: "Send"
                  onClicked: {
                    const replyText = String(replyField.text || "");
                    if (replyText.length === 0)
                      return;
                    const success = messageColumn.modelData && messageColumn.modelData.sendInlineReply ? messageColumn.modelData.sendInlineReply(replyText) : false;
                    if (success !== false)
                      replyField.text = "";
                  }
                }
              }
            }

            Loader {
              Layout.fillWidth: true
              active: messageColumn.actionsModel.length > 0
              sourceComponent: RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                Repeater {
                  model: messageColumn.actionsModel
                  delegate: StandardButton {
                    required property var modelData
                    buttonType: "action"
                    text: modelData.title || modelData.id || ""
                    onClicked: root.svc?.executeAction(messageColumn.modelData, modelData.id, modelData._obj)
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onEntered: {
      for (const w of root.items)
        if (w?.timer?.running)
          w.timer.stop();
    }
    onExited: {
      for (const w of root.items) {
        const t = w?.timer;
        if (t && (t.interval || 0) > 0 && !t.running)
          t.start();
      }
    }
  }
}
