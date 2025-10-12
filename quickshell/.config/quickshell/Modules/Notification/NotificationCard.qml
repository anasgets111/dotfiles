pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services.Utils
import qs.Config

Item {
  id: root

  property bool _animReady: false
  property var _messageExpansion: ({})
  readonly property color accentColor: root.primaryWrapper?.accentColor || Theme.activeColor
  readonly property real cardWidth: 380
  property var group: null
  readonly property bool groupExpanded: !root.isGroup || (root.svc?.expandedGroups ? (root.svc.expandedGroups[root.group.key] || false) : false)
  readonly property bool headerHasExpand: root.isGroup && root.items.length > 1
  readonly property string headerTitle: root.isGroup ? `${root.group?.appName || "app"} (${root.group?.count || root.items.length})` : (root.primaryWrapper?.appName || "app")
  readonly property bool isGroup: !!root.group
  readonly property var items: root.isGroup ? (root.group?.notifications || []) : (root.wrapper ? [root.wrapper] : [])
  readonly property var primaryWrapper: root.items.length > 0 ? root.items[0] : null
  required property var svc
  property var wrapper: null

  signal inputFocusRequested

  function messageExpanded(id) {
    return !!root._messageExpansion[id];
  }

  function toggleMessageExpansion(id) {
    if (!id)
      return;
    const next = Object.assign({}, root._messageExpansion);
    next[id] = !next[id];
    root._messageExpansion = next;
  }

  implicitHeight: cardColumn.implicitHeight + 28
  implicitWidth: root.cardWidth
  x: !root._animReady ? root.width + (Theme.popupOffset || 12) : 0

  Behavior on x {
    NumberAnimation {
      duration: (Theme.animationDuration || 200) * 1.4
      easing.type: Easing.OutCubic
    }
  }

  Component.onCompleted: Qt.callLater(() => root._animReady = true)
  Keys.onEscapePressed: {
    if (root.isGroup)
      root.svc?.dismissGroup(root.group?.key);
    else if (root.primaryWrapper)
      root.svc?.dismissNotification(root.primaryWrapper);
  }

  CardStyling {
    accentColor: root.accentColor
    anchors.fill: parent
  }

  ColumnLayout {
    id: cardColumn

    spacing: 10

    anchors {
      bottomMargin: 16
      fill: parent
      leftMargin: 12
      rightMargin: 16
      topMargin: 12
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Loader {
        Layout.preferredHeight: active ? 40 : 0
        Layout.preferredWidth: active ? 40 : 0
        active: !!root.primaryWrapper

        sourceComponent: Rectangle {
          border.color: Qt.rgba(255, 255, 255, 0.05)
          border.width: 1
          color: Qt.rgba(1, 1, 1, 0.07)
          height: 40
          radius: 8
          width: 40

          Image {
            anchors.centerIn: parent
            cache: false
            fillMode: Image.PreserveAspectFit
            height: 30
            smooth: true
            source: Utils.resolveIconSource(root.primaryWrapper?.appName || "app", root.primaryWrapper?.appIcon, "dialog-information")
            sourceSize: Qt.size(30, 30)
            width: 30

            onStatusChanged: if (status === Image.Error)
              parent.parent.active = false
          }
        }
      }

      Text {
        Layout.fillWidth: true
        color: "white"
        elide: Text.ElideRight
        font.bold: true
        font.pixelSize: 15
        horizontalAlignment: Text.AlignHCenter
        text: root.headerTitle
      }

      RowLayout {
        spacing: 6

        Loader {
          active: root.headerHasExpand

          sourceComponent: StandardButton {
            Accessible.name: root.groupExpanded ? "Collapse group" : "Expand group"
            buttonType: "control"
            text: root.groupExpanded ? "▴" : "▾"

            onClicked: root.svc?.toggleGroupExpansion(root.group?.key)
          }
        }

        StandardButton {
          Accessible.name: root.isGroup ? "Dismiss group" : "Dismiss notification"
          buttonType: "control"
          text: "x"

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
      id: messagesLayout

      readonly property var renderedItems: root.isGroup && !root.groupExpanded ? (root.items.length > 0 ? [root.items[0]] : []) : root.items

      Layout.fillWidth: true
      spacing: 12

      Repeater {
        model: parent.renderedItems

        delegate: Item {
          id: messageItem

          required property int index
          readonly property bool isHovered: hoverHandler.hovered
          readonly property bool isMultipleItems: messagesLayout.renderedItems.length > 1
          required property var modelData

          Layout.fillWidth: true
          implicitHeight: messageColumn.implicitHeight

          HoverHandler {
            id: hoverHandler

            enabled: messageItem.isMultipleItems
          }

          Rectangle {
            anchors.fill: parent
            border.color: messageItem.isMultipleItems ? (messageItem.isHovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4) : Qt.rgba(1, 1, 1, 0.1)) : "transparent"
            border.width: messageItem.isMultipleItems ? 1 : 0
            color: messageItem.isMultipleItems ? (messageItem.isHovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)) : "transparent"
            radius: 6

            Behavior on border.color {
              ColorAnimation {
                duration: 150
              }
            }
            Behavior on color {
              ColorAnimation {
                duration: 150
              }
            }
          }

          ColumnLayout {
            id: messageColumn

            readonly property var actionsModel: messageItem.modelData?.actions || []
            readonly property string body: messageItem.modelData?.body || ""
            readonly property bool bodyHasMultipleLines: (body.match(/\n/g) || []).length > 0
            property bool bodyTruncated: false
            readonly property int bottomPadding: messageItem.isMultipleItems ? 8 : 0
            readonly property url contentImage: messageItem.modelData?.cleanImage || ""
            readonly property bool expanded: root.messageExpanded(messageColumn.messageId)
            readonly property bool hasBody: messageItem.modelData?.hasBody === true || (body && body.trim() !== "" && body.trim() !== summary.trim())
            readonly property bool hasInlineReply: messageItem.modelData?.hasInlineReply === true
            readonly property int horizontalPadding: messageItem.isMultipleItems ? 8 : 0
            readonly property string inlineReplyPlaceholder: messageItem.modelData?.inlineReplyPlaceholder || "Reply"
            readonly property string messageId: messageItem.modelData?.id || String(messageItem.modelData?.notification ? messageItem.modelData.notification.id || "" : "")
            readonly property var renderedBodyMeta: messageColumn.hasBody ? prepareBody(body) : {
              text: "",
              format: Qt.PlainText
            }
            readonly property string summary: messageItem.modelData?.summary || "(No title)"
            property bool summaryTruncated: false
            readonly property int topPadding: messageItem.isMultipleItems ? 8 : 0

            function prepareBody(raw) {
              if (typeof raw !== "string" || raw.length === 0)
                return {
                  text: "",
                  format: Qt.PlainText
                };

              // Try Markdown2Html first
              try {
                if (typeof Markdown2Html !== "undefined" && typeof Markdown2Html.toDisplay === "function") {
                  const result = Markdown2Html.toDisplay(raw);
                  if (result?.format === Qt.RichText)
                    return {
                      text: result.text,
                      format: result.format
                    };
                }
              } catch (e) {}

              // Fallback: linkify URLs
              try {
                const escapeHtml = s => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\"/g, "&quot;").replace(/'/g, "&#39;");
                const escaped = escapeHtml(raw);
                const urlRegex = /((https?:\/\/|www\.)[\w\-@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([\w\-@:%_\+.~#?&//=;:,]*)?)/gi;
                const html = escaped.replace(urlRegex, m => {
                  const href = m.startsWith('http') ? m : 'https://' + m;
                  return `<a href="${href}">${m}</a>`;
                });
                return urlRegex.test(raw) ? {
                  text: html,
                  format: Qt.RichText
                } : {
                  text: raw,
                  format: Qt.PlainText
                };
              } catch (e) {
                return {
                  text: raw,
                  format: Qt.PlainText
                };
              }
            }

            spacing: 6

            anchors {
              bottomMargin: bottomPadding
              left: parent.left
              leftMargin: horizontalPadding
              right: parent.right
              rightMargin: horizontalPadding
              top: parent.top
              topMargin: topPadding
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Loader {
                Layout.preferredHeight: active ? 24 : 0
                Layout.preferredWidth: active ? 24 : 0
                active: !!messageColumn.contentImage

                sourceComponent: Image {
                  fillMode: Image.PreserveAspectFit
                  height: 24
                  smooth: true
                  source: messageColumn.contentImage
                  width: 24

                  onStatusChanged: if (status === Image.Error)
                    parent.parent.active = false
                }
              }

              Text {
                id: summaryText

                Layout.fillWidth: true
                color: "#dddddd"
                elide: Text.ElideRight
                font.pixelSize: 14
                horizontalAlignment: messageItem.isMultipleItems ? Text.AlignLeft : Text.AlignHCenter
                maximumLineCount: messageColumn.expanded ? 0 : 2
                text: messageColumn.summary
                wrapMode: Text.WordWrap

                Component.onCompleted: Qt.callLater(() => {
                  messageColumn.summaryTruncated = truncated || lineCount > 2;
                })
                onLineCountChanged: messageColumn.summaryTruncated = truncated || lineCount > 2
                onTruncatedChanged: messageColumn.summaryTruncated = truncated || lineCount > 2
              }

              RowLayout {
                spacing: 6

                Loader {
                  active: messageColumn.summaryTruncated || messageColumn.bodyTruncated || messageColumn.expanded

                  sourceComponent: StandardButton {
                    Accessible.name: messageColumn.expanded ? "Collapse message" : "Expand message"
                    buttonType: "control"
                    text: messageColumn.expanded ? "▴" : "▾"

                    onClicked: root.toggleMessageExpansion(messageColumn.messageId)
                  }
                }

                Loader {
                  active: messageItem.isMultipleItems

                  sourceComponent: StandardButton {
                    Accessible.name: "Dismiss notification"
                    buttonType: "control"
                    text: "x"

                    onClicked: {
                      if (messageItem.modelData)
                        root.svc?.dismissNotification(messageItem.modelData);
                    }
                  }
                }
              }
            }

            Loader {
              Layout.fillWidth: true
              active: messageColumn.hasBody

              sourceComponent: Item {
                Layout.fillWidth: true
                clip: !messageColumn.expanded
                implicitHeight: messageColumn.expanded ? bodyText.implicitHeight : Math.min(bodyText.implicitHeight, bodyText.font.pixelSize * 2 * 1.5)

                Text {
                  id: bodyText

                  color: "#bbbbbb"
                  font.pixelSize: 12
                  linkColor: root.accentColor
                  text: messageColumn.renderedBodyMeta.text
                  textFormat: messageColumn.renderedBodyMeta.format
                  width: parent.width
                  wrapMode: Text.WordWrap

                  Component.onCompleted: Qt.callLater(() => {
                    messageColumn.bodyTruncated = truncated || lineCount > 2 || messageColumn.bodyHasMultipleLines || implicitHeight > font.pixelSize * 2 * 1.5;
                  })
                  onLineCountChanged: {
                    messageColumn.bodyTruncated = truncated || lineCount > 2 || messageColumn.bodyHasMultipleLines || implicitHeight > font.pixelSize * 2 * 1.5;
                  }
                  onLinkActivated: url => Qt.openUrlExternally(url)
                  onTruncatedChanged: {
                    messageColumn.bodyTruncated = truncated || lineCount > 2 || messageColumn.bodyHasMultipleLines || implicitHeight > font.pixelSize * 2 * 1.5;
                  }
                }

                HoverHandler {
                  id: linkHover

                  cursorShape: bodyText.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                TapHandler {
                  acceptedButtons: Qt.LeftButton

                  onTapped: function (eventPoint) {
                    const link = bodyText.linkAt(eventPoint.position.x, eventPoint.position.y);
                    if (link) {
                      Qt.openUrlExternally(link);
                    }
                  }
                }
              }

              onActiveChanged: if (!active)
                messageColumn.bodyTruncated = false
            }

            Loader {
              Layout.bottomMargin: 6
              Layout.fillWidth: true
              Layout.topMargin: 8
              active: messageColumn.hasInlineReply

              sourceComponent: RowLayout {
                spacing: 8

                TextField {
                  id: replyField

                  Layout.fillWidth: true
                  activeFocusOnPress: true
                  font.pixelSize: 13
                  padding: 8
                  placeholderText: messageColumn.inlineReplyPlaceholder
                  selectByMouse: true

                  background: Rectangle {
                    anchors.fill: parent
                    border.color: replyField.activeFocus ? Theme.activeColor : Theme.borderColor
                    border.width: 1
                    color: Theme.bgColor
                    radius: Theme.itemRadius
                  }

                  Keys.onEnterPressed: sendBtn.clicked()
                  Keys.onReturnPressed: sendBtn.clicked()
                  onActiveFocusChanged: if (activeFocus)
                    root.inputFocusRequested()
                }

                StandardButton {
                  id: sendBtn

                  buttonType: "action"
                  text: "Send"

                  onClicked: {
                    const replyText = String(replyField.text || "");
                    if (replyText.length === 0)
                      return;
                    const success = messageItem.modelData && messageItem.modelData.sendInlineReply ? messageItem.modelData.sendInlineReply(replyText) : false;
                    if (success !== false)
                      replyField.text = "";
                  }
                }
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.preferredHeight: visible ? implicitHeight : 0
              Layout.topMargin: 8
              implicitHeight: actionsRow.implicitHeight
              spacing: 0
              visible: messageColumn.actionsModel.length > 0

              RowLayout {
                id: actionsRow

                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                implicitHeight: childrenRect.height
                spacing: 8

                Repeater {
                  model: messageColumn.actionsModel

                  delegate: StandardButton {
                    required property var modelData

                    buttonType: "action"
                    text: modelData.title || modelData.id || ""

                    onClicked: root.svc?.executeAction(messageItem.modelData, modelData.id, modelData._obj)
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  HoverHandler {
    onHoveredChanged: {
      if (hovered) {
        for (const w of root.items)
          if (w?.timer?.running)
            w.timer.stop();
      } else {
        for (const w of root.items) {
          const t = w?.timer;
          if (t && (t.interval || 0) > 0 && !t.running)
            t.start();
        }
      }
    }
  }
}
