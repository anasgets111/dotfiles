pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Modules.Bar
import qs.Services.SystemInfo

/**
 * UpdatePanel - Displays available package updates in a table format
 *
 * Shows package updates from UpdateService with:
 * - Three columns: Package, Old Version, New Version
 * - Different row colors for repo vs AUR packages
 * - Scrollable list when updates exceed maxVisibleItems
 */
LazyLoader {
  id: root

  property int maxVisibleItems: 10
  property real itemHeight: Theme.itemHeight
  property real itemPadding: 8
  property int panelWidth: 500
  property int screenMargin: 8

  property bool useButtonPosition: false
  property point buttonPosition: Qt.point(0, 0)
  property int buttonWidth: 0
  property int buttonHeight: 0

  property bool isOpen: false
  property var selectedPackages: ({}) // Map of package names to selection state
  property bool selectAll: false

  readonly property color repoRowColor: Theme.bgColor
  readonly property color aurRowColor: Qt.darker(Theme.bgColor, 1.15)
  readonly property color headerColor: Qt.lighter(Theme.bgColor, 1.74)
  readonly property int selectedCount: Object.values(selectedPackages).filter(v => v).length

  signal panelClosed

  active: isOpen

  function toggleSelectAll() {
    const newState = !selectAll;
    selectAll = newState;
    const newSelected = {};
    UpdateService.allPackages.forEach(pkg => {
      newSelected[pkg.name] = newState;
    });
    selectedPackages = newSelected;
  }

  function togglePackage(packageName) {
    const newSelected = Object.assign({}, selectedPackages);
    newSelected[packageName] = !newSelected[packageName];
    selectedPackages = newSelected;

    // Update selectAll state based on whether all packages are selected
    selectAll = UpdateService.allPackages.every(pkg => selectedPackages[pkg.name]);
  }

  function openAt(x, y) {
    buttonPosition = Qt.point(x, y);
    buttonWidth = 0;
    buttonHeight = 0;
    open();
  }

  function openAtItem(item, mouseX, mouseY) {
    if (!item)
      return;
    buttonPosition = item.mapToItem(null, mouseX || 0, mouseY || 0);
    buttonWidth = item.width;
    buttonHeight = item.height;
    open();
  }

  function open() {
    useButtonPosition = true;
    isOpen = true;
  }

  function close() {
    if (!isOpen)
      return;
    isOpen = false;
    panelClosed();
  }

  PanelWindow {
    id: panel

    readonly property bool isClosing: !root.isOpen && visible
    readonly property real headerHeight: headerRow.height
    readonly property real footerHeight: footerRow.height
    readonly property real contentHeight: Math.min(updatesList.contentHeight, root.maxVisibleItems * root.itemHeight)
    readonly property real totalContentHeight: headerHeight + contentHeight + footerHeight + root.itemPadding * 4

    color: "transparent"
    visible: root.isOpen || isClosing

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "update-panel"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    anchors {
      top: true
      left: true
      right: true
      bottom: true
    }

    function calculateX() {
      if (!root.useButtonPosition)
        return 0;
      const cornerWidth = 48; // RoundCorner width
      const centerX = root.buttonPosition.x + root.buttonWidth / 2 - panelBackground.width / 2;
      const minX = cornerWidth; // Account for left corner
      const maxX = panel.width - panelBackground.width - cornerWidth; // Account for right corner
      return Math.max(minX, Math.min(centerX, maxX));
    }

    function calculateY() {
      if (!root.useButtonPosition)
        return Math.round((panel.height - panelBackground.height) / 2);
      const belowY = Theme.panelHeight;
      const aboveY = root.buttonPosition.y - panelBackground.height - 4;
      const maxY = panel.height - panelBackground.height - 8;

      if (belowY + panelBackground.height <= panel.height - 8)
        return Math.round(belowY);
      if (aboveY >= 8)
        return Math.round(aboveY);
      return Math.round(Math.min(belowY, maxY));
    }

    Shortcut {
      sequences: ["Escape"]
      enabled: root.isOpen
      onActivated: root.close()
      context: Qt.WindowShortcut
    }

    MouseArea {
      id: dismissArea
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      hoverEnabled: false
      enabled: root.isOpen

      onPressed: function (mouse) {
        if (!panelBackground)
          return;
        const local = panelBackground.mapFromItem(dismissArea, mouse.x, mouse.y);
        const inside = local.x >= 0 && local.y >= 0 && local.x <= panelBackground.width && local.y <= panelBackground.height;

        if (inside) {
          mouse.accepted = false;
          return;
        }

        root.close();
      }
    }

    // Clip container to prevent panel from appearing above the bar
    Item {
      id: clipContainer
      anchors.fill: parent
      anchors.topMargin: Theme.panelHeight
      clip: true

      Rectangle {
        id: panelBackground

        readonly property real targetY: panel.calculateY() - Theme.panelHeight
        readonly property real hiddenY: -panel.totalContentHeight

        width: root.panelWidth
        height: panel.totalContentHeight

        color: Theme.bgColor
        radius: Theme.itemRadius

        // Only round bottom corners
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Theme.itemRadius
        bottomRightRadius: Theme.itemRadius

        x: panel.calculateX()
        y: root.isOpen ? targetY : hiddenY

        Behavior on y {
          PanelAnimation {}
        }

        clip: true

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: root.itemPadding
          spacing: 4

          // Header row with column titles
          Rectangle {
            id: headerRow
            Layout.fillWidth: true
            Layout.preferredHeight: root.itemHeight
            color: root.headerColor
            radius: Theme.itemRadius

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: root.itemPadding
              anchors.rightMargin: root.itemPadding
              spacing: 8

              // Select All checkbox
              Rectangle {
                Layout.preferredWidth: root.itemHeight * 0.6
                Layout.preferredHeight: root.itemHeight * 0.6
                color: "transparent"
                border.color: Theme.textContrast(root.headerColor)
                border.width: 2
                radius: 4

                Rectangle {
                  anchors.centerIn: parent
                  width: parent.width * 0.6
                  height: parent.height * 0.6
                  color: Theme.activeColor
                  radius: 2
                  visible: root.selectAll
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleSelectAll()
                }
              }

              Text {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width * 0.35
                text: qsTr("Package")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                color: Theme.textContrast(root.headerColor)
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
              }

              Text {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width * 0.3
                text: qsTr("Old Version")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                color: Theme.textContrast(root.headerColor)
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
              }

              Text {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width * 0.3
                text: qsTr("New Version")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                color: Theme.textContrast(root.headerColor)
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
              }
            }
          }

          // Updates list
          ListView {
            id: updatesList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, root.maxVisibleItems * root.itemHeight)
            spacing: 2
            interactive: contentHeight > height
            clip: true
            model: UpdateService.allPackages

            ScrollBar.vertical: ScrollBar {
              policy: updatesList.contentHeight > updatesList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
              width: 8
            }

            delegate: Rectangle {
              id: updateRow

              required property var modelData
              required property int index

              readonly property bool isAur: modelData.source === "aur"
              readonly property string packageName: modelData.name || ""
              readonly property string oldVersion: modelData.oldVersion || ""
              readonly property string newVersion: modelData.newVersion || ""
              readonly property color baseColor: isAur ? root.aurRowColor : root.repoRowColor
              readonly property color hoverColor: Qt.lighter(baseColor, 1.47)

              width: updatesList.width
              height: root.itemHeight
              color: rowHover.containsMouse ? hoverColor : baseColor
              radius: Theme.itemRadius * 0.5

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animationDuration * 0.7
                  easing.type: Easing.OutQuad
                }
              }

              MouseArea {
                id: rowHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePackage(updateRow.packageName)
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.itemPadding
                anchors.rightMargin: root.itemPadding
                spacing: 8

                // Package checkbox
                Rectangle {
                  Layout.preferredWidth: root.itemHeight * 0.6
                  Layout.preferredHeight: root.itemHeight * 0.6
                  color: "transparent"
                  border.color: Theme.textActiveColor
                  border.width: 2
                  radius: 4

                  Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.6
                    height: parent.height * 0.6
                    color: Theme.activeColor
                    radius: 2
                    visible: root.selectedPackages[updateRow.packageName] || false
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePackage(updateRow.packageName)
                  }
                }

                Text {
                  Layout.fillWidth: true
                  Layout.preferredWidth: parent.width * 0.35
                  text: updateRow.packageName
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize
                  color: Theme.textActiveColor
                  elide: Text.ElideRight
                  verticalAlignment: Text.AlignVCenter
                }

                Text {
                  Layout.fillWidth: true
                  Layout.preferredWidth: parent.width * 0.3
                  text: updateRow.oldVersion
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize
                  color: Theme.textInactiveColor
                  elide: Text.ElideRight
                  verticalAlignment: Text.AlignVCenter
                }

                Text {
                  Layout.fillWidth: true
                  Layout.preferredWidth: parent.width * 0.3
                  text: updateRow.newVersion
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize
                  color: Theme.activeColor
                  elide: Text.ElideRight
                  verticalAlignment: Text.AlignVCenter
                }
              }
            }
          }

          // Footer with action buttons
          RowLayout {
            id: footerRow
            Layout.fillWidth: true
            Layout.preferredHeight: root.itemHeight
            spacing: 8

            Rectangle {
              id: updateSelectedBtn
              Layout.fillWidth: true
              Layout.preferredHeight: root.itemHeight
              color: updateSelectedMouse.enabled ? (updateSelectedMouse.containsMouse ? Theme.onHoverColor : Theme.activeColor) : Theme.disabledColor
              radius: Theme.itemRadius

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animationDuration
                }
              }

              RowLayout {
                anchors.centerIn: parent
                spacing: 4

                Text {
                  text: "󰚰"
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize
                  color: Theme.textContrast(updateSelectedBtn.color)
                  visible: root.selectedCount > 0
                }

                Text {
                  text: root.selectedCount > 0 ? `Selected (${root.selectedCount})` : qsTr("Select packages")
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize
                  font.bold: true
                  color: Theme.textContrast(updateSelectedBtn.color)
                }
              }

              MouseArea {
                id: updateSelectedMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.selectedCount > 0
                onClicked: {
                  // TODO: Implement update selected packages
                  // For now, just show which packages would be updated
                  const selected = Object.keys(root.selectedPackages).filter(k => root.selectedPackages[k]);
                  console.log("Would update:", selected.join(", "));
                  root.close();
                }
              }
            }

            Rectangle {
              id: updateAllBtn
              Layout.fillWidth: true
              Layout.preferredHeight: root.itemHeight
              color: updateAllMouse.containsMouse ? Theme.onHoverColor : Theme.activeColor
              radius: Theme.itemRadius

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animationDuration
                }
              }

              Text {
                anchors.centerIn: parent
                text: qsTr("Update All")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                color: Theme.textContrast(updateAllBtn.color)
              }

              MouseArea {
                id: updateAllMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  UpdateService.runUpdate();
                  root.close();
                }
              }
            }

            Rectangle {
              id: cancelBtn
              Layout.fillWidth: true
              Layout.preferredHeight: root.itemHeight
              color: cancelMouse.enabled ? (cancelMouse.containsMouse ? Theme.onHoverColor : Theme.inactiveColor) : Theme.disabledColor
              radius: Theme.itemRadius

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animationDuration
                }
              }

              Text {
                anchors.centerIn: parent
                text: qsTr("Cancel")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                color: Theme.textContrast(cancelBtn.color)
              }

              MouseArea {
                id: cancelMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: false // Disabled for now
                onClicked:
                // TODO: Implement cancel
                {}
              }
            }
          }
        }
      }

      // Left inverse corner
      RoundCorner {
        anchors.right: panelBackground.left
        anchors.rightMargin: -1
        y: panelBackground.y
        color: Theme.bgColor
        orientation: 1 // TOP_RIGHT
        radius: Theme.panelRadius * 3
      }

      // Right inverse corner
      RoundCorner {
        anchors.left: panelBackground.right
        anchors.leftMargin: -1
        y: panelBackground.y
        color: Theme.bgColor
        orientation: 0 // TOP_LEFT
        radius: Theme.panelRadius * 3
      }
    }
  }

  component PanelAnimation: NumberAnimation {
    duration: Theme.animationDuration
    easing.type: Easing.OutQuad
  }
}
