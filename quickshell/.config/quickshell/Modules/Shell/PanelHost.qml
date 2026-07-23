pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Components
import qs.Config
import qs.Modules.Bar.Panels

FocusScope {
  id: root

  property bool active: false
  property rect anchorRect: Qt.rect(0, 0, 0, 0)
  readonly property Region blurClipRegion: Region {
    intersection: Intersection.Intersect
    item: panelClipArea
  }
  readonly property Region blurRegion: Region {
    bottomLeftRadius: panelBackground.bottomLeftRadius
    bottomRightRadius: panelBackground.bottomRightRadius
    item: panelBackground
    regions: [leftCorner.region, rightCorner.region, root.blurClipRegion]
  }
  readonly property bool contentActive: root.active || closeHoldTimer.running
  readonly property real cornerCutRadius: Math.min(Theme.panelRadius * 3, Theme.panelHeight)
  readonly property rect effectiveAnchorRect: root.active ? root.anchorRect : root.retainedAnchorRect
  readonly property var effectivePanelComponent: root.active ? root.panelComponent : (root.contentActive ? root.retainedPanelComponent : null)
  readonly property var effectivePanelData: root.active ? (root.panelComponent !== null ? root.panelData : null) : root.retainedPanelData
  readonly property real effectivePanelHeight: root.active ? root.livePanelHeight : root.retainedPanelHeight
  readonly property real effectivePanelWidth: root.active ? root.panelContentWidth : root.retainedPanelWidth
  readonly property real livePanelHeight: Math.min(root.panelContentHeight, root.height - Theme.panelHeight - Theme.panelScreenInset)
  readonly property bool needsKeyboardFocus: root.panelItem?.needsKeyboardFocus ?? false
  readonly property var panelComponent: ({
      "audio": audioPanelComponent,
      "bluetooth": bluetoothPanelComponent,
      "media": mediaPanelComponent,
      "network": networkPanelComponent,
      "notifications": notificationPanelComponent,
      "updates": updatesPanelComponent,
      "tray": trayPanelComponent
    })[panelId] ?? null
  readonly property real panelContentHeight: Math.max(1, root.panelItem?.preferredHeight ?? 0)
  readonly property real panelContentWidth: Math.max(1, root.panelItem?.preferredWidth ?? Theme.panelDefaultWidth)
  property var panelData: null
  property string panelId: ""
  readonly property PanelContentBase panelItem: panelLoader.item as PanelContentBase
  property bool _revealed: false
  property rect retainedAnchorRect: Qt.rect(0, 0, 0, 0)
  property var retainedPanelComponent: null
  property var retainedPanelData: null
  property real retainedPanelHeight: 1
  property real retainedPanelWidth: Theme.panelDefaultWidth
  readonly property bool useFlatContainer: root.panelItem?.flatContainer ?? false

  signal closeRequested

  function calculateX() {
    const centerX = root.effectiveAnchorRect.x + root.effectiveAnchorRect.width / 2 - panelBackground.width / 2;
    const minX = Theme.spacingSm + root.cornerCutRadius;
    const maxX = root.width - panelBackground.width - Theme.spacingSm - root.cornerCutRadius;
    return Math.max(minX, Math.min(centerX, maxX));
  }
  function calculateY() {
    const belowY = Theme.panelHeight;
    const aboveY = root.effectiveAnchorRect.y - panelBackground.height - Theme.panelAnchorGap;
    const maxY = root.height - panelBackground.height - Theme.panelScreenInset;

    if (belowY + panelBackground.height <= root.height - Theme.panelScreenInset)
      return Math.round(belowY);
    if (aboveY >= Theme.panelScreenInset)
      return Math.round(aboveY);
    return Math.round(Math.min(belowY, maxY));
  }
  function revealPanel(): void {
    if (root.active && root.panelItem)
      root._revealed = true;
  }

  focus: root.active
  visible: root.contentActive || panelBackground.y > panelBackground.hiddenY

  Keys.onPressed: event => {
    if (root.active && event.key === Qt.Key_Escape) {
      root.closeRequested();
      event.accepted = true;
    }
  }
  onActiveChanged: {
    if (root.active) {
      root.retainedAnchorRect = root.anchorRect;
      root.retainedPanelHeight = root.livePanelHeight;
      root.retainedPanelWidth = root.panelContentWidth;
      if (closeHoldTimer.running)
        closeHoldTimer.stop();
      if (panelLoader.status === Loader.Ready)
        Qt.callLater(root.revealPanel);
    } else {
      root._revealed = false;
      if (panelBackground.y > panelBackground.hiddenY) {
        root.retainedPanelHeight = panelBackground.height;
        root.retainedPanelWidth = panelBackground.width;
        closeHoldTimer.restart();
      }
    }
  }
  onAnchorRectChanged: if (root.active && root.panelComponent !== null)
    root.retainedAnchorRect = root.anchorRect
  onPanelComponentChanged: {
    if (root.panelComponent === null)
      return;
    root.retainedPanelComponent = root.panelComponent;
    if (root.active)
      root._revealed = false;
  }
  onPanelContentHeightChanged: if (root.active && root.panelComponent !== null)
    root.retainedPanelHeight = root.livePanelHeight
  onPanelContentWidthChanged: if (root.active && root.panelComponent !== null)
    root.retainedPanelWidth = root.panelContentWidth
  onPanelDataChanged: root.retainedPanelData = root.panelData
  onPanelIdChanged: if (root.active && root.panelId.length > 0 && root.panelComponent === null)
    root.closeRequested()

  Timer {
    id: closeHoldTimer

    interval: Theme.animationDuration
    repeat: false

    onTriggered: if (!root.active) {
      root.retainedAnchorRect = Qt.rect(0, 0, 0, 0);
      root.retainedPanelComponent = null;
      root.retainedPanelData = null;
      root.retainedPanelHeight = 1;
      root.retainedPanelWidth = Theme.panelDefaultWidth;
    }
  }
  MouseArea {
    id: dismissArea

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    anchors.fill: parent
    enabled: root.active

    onPressed: mouse => {
      const local = panelBackground.mapFromItem(dismissArea, mouse.x, mouse.y);
      const inside = local.x >= 0 && local.y >= 0 && local.x <= panelBackground.width && local.y <= panelBackground.height;
      if (inside) {
        mouse.accepted = false;
        return;
      }
      root.closeRequested();
    }
  }
  Item {
    id: panelClipArea

    anchors.fill: parent
    anchors.topMargin: Theme.panelHeight
    clip: true

    Rectangle {
      id: panelBackground

      readonly property real hiddenY: -height
      property real revealProgress: root._revealed ? 1 : 0
      readonly property real targetY: root.calculateY() - Theme.panelHeight

      bottomLeftRadius: root.useFlatContainer ? Theme.panelRadius * 2 : Theme.itemRadius
      bottomRightRadius: root.useFlatContainer ? Theme.panelRadius * 2 : Theme.itemRadius
      clip: true
      color: Theme.glassSurfaceColor
      height: root.effectivePanelHeight
      radius: root.useFlatContainer ? 0 : Theme.itemRadius
      topLeftRadius: 0
      topRightRadius: 0
      visible: panelLoader.active
      width: root.effectivePanelWidth
      x: root.calculateX()
      y: hiddenY + (targetY - hiddenY) * revealProgress

      Behavior on height {
        enabled: root._revealed

        NumberAnimation {
          duration: Theme.animationSlow
          easing.type: Easing.OutCubic
        }
      }
      Behavior on revealProgress {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.OutQuad
        }
      }

      Loader {
        id: panelLoader

        active: root.contentActive && root.effectivePanelComponent !== null
        anchors.fill: parent
        sourceComponent: root.effectivePanelComponent

        onLoaded: {
          if (!root.panelItem)
            return;
          root.panelItem.width = Qt.binding(() => panelLoader.width);
          root.panelItem.height = Qt.binding(() => panelLoader.height);
          root.panelItem.isOpen = Qt.binding(() => root.active);
          root.panelItem.panelData = Qt.binding(() => root.effectivePanelData);
          Qt.callLater(root.revealPanel);
        }
      }
    }
    RoundCorner {
      id: leftCorner

      anchors.right: panelBackground.left
      color: Theme.glassSurfaceColor
      height: root.cornerCutRadius
      orientation: 1
      radius: root.cornerCutRadius
      visible: panelBackground.visible
      width: root.cornerCutRadius
      y: panelBackground.y
    }
    RoundCorner {
      id: rightCorner

      anchors.left: panelBackground.right
      color: Theme.glassSurfaceColor
      height: root.cornerCutRadius
      orientation: 0
      radius: root.cornerCutRadius
      visible: panelBackground.visible
      width: root.cornerCutRadius
      y: panelBackground.y
    }
  }
  Connections {
    function onCloseRequested() {
      root.closeRequested();
    }

    target: root.panelItem
  }
  Component {
    id: audioPanelComponent

    AudioPanel {
    }
  }
  Component {
    id: bluetoothPanelComponent

    BluetoothPanel {
    }
  }
  Component {
    id: mediaPanelComponent

    MediaPanel {
    }
  }
  Component {
    id: networkPanelComponent

    NetworkPanel {
    }
  }
  Component {
    id: notificationPanelComponent

    NotificationHistoryPanel {
    }
  }
  Component {
    id: updatesPanelComponent

    UpdatePanel {
    }
  }
  Component {
    id: trayPanelComponent

    TrayMenuPanel {
    }
  }
}
