pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Components
import qs.Services.Utils
import qs.Config

Item {
  id: root

  property bool _animReady: false
  property var _messageExpansion: ({})
  readonly property color accentColor: root.primaryWrapper?.accentColor || Theme.activeColor
  readonly property real cardWidth: 380
  required property var group
  readonly property bool groupExpanded: !root.isGroup || (root.svc?.expandedGroups ? (root.svc.expandedGroups[root.group.key] || false) : false)
  readonly property bool headerHasExpand: root.isGroup && root.items.length > 1
  readonly property string headerTitle: root.isGroup ? `${root.group?.appName || "app"} (${root.group?.count || root.items.length})` : (root.primaryWrapper?.appName || "app")
  readonly property bool isGroup: (root.group?.count || 0) > 1
  readonly property var items: root.group?.notifications || []
  readonly property int messagePadding: Theme.spacingSm
  readonly property int paddingHorizontal: Theme.spacingMd
  readonly property int paddingVertical: Theme.spacingMd
  readonly property var primaryWrapper: root.items.length > 0 ? root.items[0] : null
  property bool showTimestamp: false
  readonly property int spacingContent: Theme.spacingXs + 2
  readonly property int spacingMessages: Theme.spacingSm
  required property var svc

  signal inputFocusReleased
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

  implicitHeight: cardColumn.implicitHeight + (root.paddingVertical * 2)
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

    spacing: root.spacingContent

    anchors {
      bottomMargin: root.paddingVertical
      fill: parent
      leftMargin: root.paddingHorizontal
      rightMargin: root.paddingHorizontal
      topMargin: root.paddingVertical
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.cardPadding

      Rectangle {
        Layout.preferredHeight: 40
        Layout.preferredWidth: 40
        border.color: Qt.rgba(255, 255, 255, 0.05)
        border.width: 1
        color: Qt.rgba(1, 1, 1, 0.07)
        radius: Theme.radiusSm
        visible: !!root.primaryWrapper

        Image {
          anchors.centerIn: parent
          fillMode: Image.PreserveAspectFit
          height: Theme.itemHeight
          smooth: true
          source: root.primaryWrapper ? Utils.resolveIconSource(root.primaryWrapper.appName || "app", root.primaryWrapper.appIcon, "dialog-information") : ""
          sourceSize: Qt.size(Theme.itemHeight, Theme.itemHeight)
          width: Theme.itemHeight
        }
      }

      OText {
        Layout.fillWidth: true
        bold: true
        color: "white"
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        text: root.headerTitle
      }

      RowLayout {
        spacing: Theme.spacingXs

        StandardButton {
          Accessible.name: root.groupExpanded ? "Collapse group" : "Expand group"
          buttonType: "control"
          text: root.groupExpanded ? "▴" : "▾"
          visible: root.headerHasExpand

          onClicked: root.svc?.toggleGroupExpansion(root.group?.key)
        }

        StandardButton {
          Accessible.name: root.isGroup ? "Dismiss group" : "Dismiss notification"
          buttonType: "control"
          text: "x"

          onClicked: root.isGroup ? root.svc?.dismissGroup(root.group?.key) : root.svc?.dismissNotification(root.primaryWrapper)
        }
      }
    }

    ColumnLayout {
      id: messagesLayout

      readonly property var renderedItems: root.isGroup && !root.groupExpanded ? (root.items.length > 0 ? [root.items[0]] : []) : root.items

      Layout.fillWidth: true
      spacing: root.spacingMessages

      Repeater {
        model: parent.renderedItems

        delegate: Item {
          id: messageItem

          required property int index
          readonly property bool isHovered: hoverHandler.hovered
          readonly property bool isMultipleItems: messagesLayout.renderedItems.length > 1
          required property var modelData

          Layout.fillWidth: true
          implicitHeight: messageColumn.implicitHeight + messageColumn.topPadding + messageColumn.bottomPadding

          HoverHandler {
            id: hoverHandler

            enabled: messageItem.isMultipleItems
          }

          Rectangle {
            anchors.fill: parent
            border.color: messageItem.isMultipleItems ? (messageItem.isHovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4) : Qt.rgba(1, 1, 1, 0.1)) : "transparent"
            border.width: messageItem.isMultipleItems ? 1 : 0
            color: messageItem.isMultipleItems ? (messageItem.isHovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)) : "transparent"
            radius: Theme.radiusSm

            Behavior on border.color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }

          ColumnLayout {
            id: messageColumn

            readonly property var actionsModel: messageItem.modelData?.actions || []
            readonly property string body: messageItem.modelData?.body || ""
            readonly property bool bodyHasMultipleLines: (body.match(/\n/g) || []).length > 0
            property bool bodyTruncated: false
            readonly property int bottomPadding: messageItem.isMultipleItems ? root.messagePadding : 0
            readonly property url contentImage: messageItem.modelData?.cleanImage || ""
            readonly property bool expanded: root.messageExpanded(messageColumn.messageId)
            readonly property bool hasBody: messageItem.modelData?.hasBody === true || (body && body.trim() !== "" && body.trim() !== summary.trim())
            readonly property bool hasInlineReply: messageItem.modelData?.hasInlineReply === true
            readonly property int horizontalPadding: messageItem.isMultipleItems ? root.messagePadding : 0
            readonly property string inlineReplyPlaceholder: messageItem.modelData?.inlineReplyPlaceholder || "Reply"
            readonly property string messageId: messageItem.modelData?.id || String(messageItem.modelData?.notification ? messageItem.modelData.notification.id || "" : "")
            readonly property var renderedBodyMeta: messageItem.modelData?.bodyMeta || {
              text: "",
              format: Qt.PlainText
            }
            readonly property string summary: messageItem.modelData?.summary || "(No title)"
            property bool summaryTruncated: false
            readonly property int topPadding: messageItem.isMultipleItems ? root.messagePadding : 0

            spacing: root.spacingContent

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
              spacing: Theme.spacingSm

              Image {
                Layout.preferredHeight: visible ? 24 : 0
                Layout.preferredWidth: visible ? 24 : 0
                fillMode: Image.PreserveAspectFit
                smooth: true
                source: messageColumn.contentImage
                visible: String(messageColumn.contentImage) !== "" && status !== Image.Error
              }

              Text {
                id: summaryText

                Layout.fillWidth: true
                color: "#dddddd"
                elide: Text.ElideRight
                font.pixelSize: Theme.fontMd
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

              OText {
                color: Theme.textInactiveColor
                opacity: 0.7
                size: "xs"
                text: messageItem.modelData?.historyTimeStr || ""
                visible: root.showTimestamp && text
              }

              RowLayout {
                spacing: Theme.spacingXs

                StandardButton {
                  Accessible.name: messageColumn.expanded ? "Collapse message" : "Expand message"
                  buttonType: "control"
                  text: messageColumn.expanded ? "▴" : "▾"
                  visible: messageColumn.summaryTruncated || messageColumn.bodyTruncated || messageColumn.expanded

                  onClicked: root.toggleMessageExpansion(messageColumn.messageId)
                }

                StandardButton {
                  Accessible.name: "Dismiss notification"
                  buttonType: "control"
                  text: "x"
                  visible: messageItem.isMultipleItems

                  onClicked: root.svc?.dismissNotification(messageItem.modelData)
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
                  font.pixelSize: Theme.fontSm
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
              Layout.bottomMargin: Theme.spacingXs
              Layout.fillWidth: true
              Layout.topMargin: Theme.spacingXs
              active: messageColumn.hasInlineReply
              visible: active

              sourceComponent: RowLayout {
                spacing: Theme.spacingSm

                TextField {
                  id: replyField

                  Layout.fillWidth: true
                  activeFocusOnPress: true
                  font.pixelSize: Theme.fontSm
                  padding: Theme.spacingSm
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
                  onActiveFocusChanged: {
                    if (activeFocus)
                      root.inputFocusRequested();
                    else
                      root.inputFocusReleased();
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
              Layout.topMargin: Theme.spacingXs
              implicitHeight: actionsRow.implicitHeight
              visible: messageColumn.actionsModel.length > 0

              RowLayout {
                id: actionsRow

                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                implicitHeight: childrenRect.height
                spacing: Theme.spacingSm

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
          // Only restart if popup is still active and timer has non-zero interval
          if (t && w.popup && (t.interval || 0) > 0 && !t.running)
            t.start();
        }
      }
    }
  }
}
