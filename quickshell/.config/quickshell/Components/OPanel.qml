pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Components
import qs.Modules.Bar.Panels

Item {
  id: root

  property bool active: false
  property rect anchorRect: Qt.rect(0, 0, 0, 0)
  readonly property bool contentActive: root.active || closeHoldTimer.running
  readonly property rect effectiveAnchorRect: root.active ? root.anchorRect : root.retainedAnchorRect
  readonly property var effectivePanelComponent: root.active ? root.panelComponent : (root.contentActive ? root.retainedPanelComponent : null)
  readonly property var effectivePanelData: root.active ? (root.panelComponent !== null ? root.panelData : null) : root.retainedPanelData
  readonly property real effectivePanelHeight: root.active ? root.livePanelHeight : root.retainedPanelHeight
  readonly property real effectivePanelWidth: root.active ? root.panelContentWidth : root.retainedPanelWidth
  readonly property real livePanelHeight: Math.min(root.panelContentHeight, root.height - Theme.panelHeight - 8)
  readonly property bool needsKeyboardFocus: root.panelItem?.needsKeyboardFocus ?? false
  readonly property var panelComponent: panelComponentMap[panelId] ?? null
  readonly property var panelComponentMap: ({
      "audio": audioPanelComponent,
      "bluetooth": bluetoothPanelComponent,
      "network": networkPanelComponent,
      "notifications": notificationPanelComponent,
      "updates": updatesPanelComponent,
      "tray": trayPanelComponent
    })
  readonly property real panelContentHeight: Math.max(1, root.panelItem?.preferredHeight ?? 0)
  readonly property real panelContentWidth: Math.max(1, root.panelItem?.preferredWidth ?? 350)
  property var panelData: null
  property string panelId: ""
  readonly property PanelContentBase panelItem: panelLoader.item as PanelContentBase
  property rect retainedAnchorRect: Qt.rect(0, 0, 0, 0)
  property var retainedPanelComponent: null
  property var retainedPanelData: null
  property real retainedPanelHeight: 1
  property real retainedPanelWidth: 350
  property int screenMargin: Theme.spacingSm
  readonly property bool useFlatContainer: root.effectivePanelComponent === audioPanelComponent || root.effectivePanelComponent === bluetoothPanelComponent || root.effectivePanelComponent === networkPanelComponent
  property bool showInverseCorners: true

  signal closeRequested

  function calculateX() {
    const cornerInset = root.showInverseCorners ? Theme.panelRadius * 3 : 0;
    const centerX = root.effectiveAnchorRect.x + root.effectiveAnchorRect.width / 2 - panelBackground.width / 2;
    const minX = root.screenMargin + cornerInset;
    const maxX = root.width - panelBackground.width - root.screenMargin - cornerInset;
    return Math.max(minX, Math.min(centerX, maxX));
  }

  function calculateY() {
    const belowY = Theme.panelHeight;
    const aboveY = root.effectiveAnchorRect.y - panelBackground.height - 4;
    const maxY = root.height - panelBackground.height - 8;

    if (belowY + panelBackground.height <= root.height - 8)
      return Math.round(belowY);
    if (aboveY >= 8)
      return Math.round(aboveY);
    return Math.round(Math.min(belowY, maxY));
  }

  visible: root.contentActive || panelBackground.y > panelBackground.hiddenY

  onActiveChanged: {
    if (root.active) {
      root.retainedAnchorRect = root.anchorRect;
      root.retainedPanelHeight = root.livePanelHeight;
      root.retainedPanelWidth = root.panelContentWidth;
      if (closeHoldTimer.running)
        closeHoldTimer.stop();
    } else if (panelBackground.y > panelBackground.hiddenY) {
      root.retainedPanelHeight = panelBackground.height;
      root.retainedPanelWidth = panelBackground.width;
      closeHoldTimer.restart();
    }
  }
  onAnchorRectChanged: if (root.active && root.panelComponent !== null)
    root.retainedAnchorRect = root.anchorRect
  onPanelComponentChanged: if (root.panelComponent !== null)
    root.retainedPanelComponent = root.panelComponent
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
      root.retainedPanelWidth = 350;
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
    anchors.fill: parent
    anchors.topMargin: Theme.panelHeight
    clip: true

    Rectangle {
      id: panelBackground

      readonly property real hiddenY: -height
      readonly property real targetY: root.calculateY() - Theme.panelHeight

      bottomLeftRadius: root.useFlatContainer ? Theme.panelRadius * 2 : Theme.itemRadius
      bottomRightRadius: root.useFlatContainer ? Theme.panelRadius * 2 : Theme.itemRadius
      clip: true
      color: Theme.bgColor
      height: root.effectivePanelHeight
      radius: root.useFlatContainer ? 0 : Theme.itemRadius
      topLeftRadius: 0
      topRightRadius: 0
      visible: panelLoader.active
      width: root.effectivePanelWidth
      x: root.calculateX()
      y: root.active ? targetY : hiddenY

      Behavior on height {
        NumberAnimation {
          duration: 300
          easing.type: Easing.OutCubic
        }
      }
      Behavior on y {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.OutQuad
        }
      }

      border {
        color: Theme.borderLight
        width: root.useFlatContainer ? 0 : 1
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
        }
      }
    }

    Loader {
      active: root.showInverseCorners && root.visible
      anchors.right: panelBackground.left
      anchors.rightMargin: -1
      y: panelBackground.y

      sourceComponent: RoundCorner {
        color: Theme.bgColor
        orientation: 1
        radius: Theme.panelRadius * 3
      }
    }

    Loader {
      active: root.showInverseCorners && root.visible
      anchors.left: panelBackground.right
      anchors.leftMargin: -1
      y: panelBackground.y

      sourceComponent: RoundCorner {
        color: Theme.bgColor
        orientation: 0
        radius: Theme.panelRadius * 3
      }
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
