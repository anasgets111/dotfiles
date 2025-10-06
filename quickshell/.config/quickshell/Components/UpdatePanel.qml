pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Wayland
import QtQuick.Controls
import qs.Config
import qs.Modules.Bar
import qs.Services.SystemInfo
import qs.Services.WM

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

  readonly property color headerColor: Qt.lighter(Theme.bgColor, 1.74)

  signal panelClosed

  active: true
  loading: true

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
    readonly property real downloadSizeHeight: root.itemHeight * 0.6
    readonly property real contentHeight: Math.min(updatesList.contentHeight, root.maxVisibleItems * root.itemHeight)
    readonly property real columnSpacing: 4
    readonly property real spacingTotal: columnSpacing * 3 // 3 gaps between 4 items
    readonly property real totalContentHeight: headerHeight + contentHeight + downloadSizeHeight + footerHeight + spacingTotal + root.itemPadding * 2
    readonly property int currentViewIndex: {
      switch (UpdateService.updateState) {
      case UpdateService.status.Idle:
        return 0;
      case UpdateService.status.Updating:
        return 1;
      case UpdateService.status.Completed:
      case UpdateService.status.Error:
        return 2;
      default:
        return 0;
      }
    }

    screen: MonitorService.effectiveMainScreen
    color: "transparent"
    visible: root.isOpen || isClosing

    mask: Region {
      item: maskItem
      intersection: root.isOpen ? Intersection.Combine : Intersection.Xor
    }

    Item {
      id: maskItem
      anchors.fill: parent
    }

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
      const cornerWidth = 48;
      const centerX = root.buttonPosition.x + root.buttonWidth / 2 - panelBackground.width / 2;
      const minX = cornerWidth;
      const maxX = panel.width - panelBackground.width - cornerWidth;
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
      enabled: root.isOpen

      onPressed: mouse => {
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
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Theme.itemRadius
        bottomRightRadius: Theme.itemRadius
        x: panel.calculateX()
        y: root.isOpen ? targetY : hiddenY

        Behavior on y {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutQuad
          }
        }

        clip: true

        StackLayout {
          anchors.fill: parent
          anchors.margins: root.itemPadding
          currentIndex: panel.currentViewIndex

          // View 0: Package List
          ColumnLayout {
            spacing: 4

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
                    visible: UpdateService.selectAll
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UpdateService.toggleSelectAll()
                  }
                }

                StyledText {
                  Layout.fillWidth: true
                  Layout.preferredWidth: parent.width * 0.35
                  text: qsTr("Package")
                  font.bold: true
                  color: Theme.textContrast(root.headerColor)
                }

                StyledText {
                  Layout.fillWidth: true
                  Layout.preferredWidth: parent.width * 0.3
                  text: qsTr("Old Version")
                  font.bold: true
                  color: Theme.textContrast(root.headerColor)
                }

                StyledText {
                  Layout.fillWidth: true
                  Layout.preferredWidth: parent.width * 0.3
                  text: qsTr("New Version")
                  font.bold: true
                  color: Theme.textContrast(root.headerColor)
                }
              }
            }

            ListView {
              id: updatesList
              Layout.fillWidth: true
              Layout.preferredHeight: Math.min(contentHeight, root.maxVisibleItems * root.itemHeight)
              spacing: 2
              interactive: contentHeight > height
              clip: true
              model: UpdateService.updatePackages

              ScrollBar.vertical: ScrollBar {
                policy: updatesList.contentHeight > updatesList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                width: 8
              }

              delegate: Rectangle {
                id: updateRow
                required property var modelData
                required property int index

                readonly property string packageName: modelData.name || ""
                readonly property string oldVersion: modelData.oldVersion || ""
                readonly property string newVersion: modelData.newVersion || ""

                width: updatesList.width
                height: root.itemHeight
                color: rowHover.containsMouse ? Qt.lighter(Theme.bgColor, 1.47) : Theme.bgColor
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
                  onClicked: UpdateService.togglePackage(updateRow.packageName)
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: root.itemPadding
                  anchors.rightMargin: root.itemPadding
                  spacing: 8

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
                      visible: UpdateService.selectedPackages[updateRow.packageName] || false
                    }
                  }

                  StyledText {
                    Layout.fillWidth: true
                    Layout.preferredWidth: parent.width * 0.35
                    text: updateRow.packageName
                  }

                  StyledText {
                    Layout.fillWidth: true
                    Layout.preferredWidth: parent.width * 0.3
                    text: updateRow.oldVersion
                    color: Theme.textInactiveColor
                  }

                  StyledText {
                    Layout.fillWidth: true
                    Layout.preferredWidth: parent.width * 0.3
                    text: updateRow.newVersion
                    color: Theme.activeColor
                  }
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: root.itemHeight * 0.6
              color: "transparent"

              RowLayout {
                anchors.centerIn: parent
                spacing: 4

                StyledText {
                  text: "󰇚"
                  color: Theme.textInactiveColor
                  opacity: 0.7
                }

                StyledText {
                  text: qsTr("Total download: %1").arg(SystemInfoService.fmtKib(UpdateService.totalDownloadSize))
                  font.pixelSize: Theme.fontSize * 0.9
                  color: Theme.textInactiveColor
                  opacity: 0.8
                }
              }
            }

            RowLayout {
              id: footerRow
              Layout.fillWidth: true
              Layout.preferredHeight: root.itemHeight
              spacing: 8

              ClickableRect {
                id: selectBtn
                Layout.fillWidth: true
                Layout.preferredHeight: root.itemHeight
                readonly property bool btnEnabled: UpdateService.selectedCount > 0
                color: btnEnabled ? Theme.activeColor : Theme.disabledColor
                radius: Theme.itemRadius
                onClicked: if (btnEnabled)
                  UpdateService.executeUpdate()

                StyledText {
                  anchors.centerIn: parent
                  text: UpdateService.selectedCount > 0 ? qsTr("Update Selected (%1)").arg(UpdateService.selectedCount) : qsTr("Select packages")
                  font.bold: true
                  color: Theme.textContrast(selectBtn.color)
                }
              }

              ClickableRect {
                id: updateAllBtn
                Layout.fillWidth: true
                Layout.preferredHeight: root.itemHeight
                color: Theme.activeColor
                radius: Theme.itemRadius
                onClicked: {
                  UpdateService.resetSelection();
                  UpdateService.executeUpdate();
                }

                StyledText {
                  anchors.centerIn: parent
                  text: qsTr("Update All")
                  font.bold: true
                  color: Theme.textContrast(updateAllBtn.color)
                }
              }

              ClickableRect {
                id: cancelBtn
                Layout.fillWidth: true
                Layout.preferredHeight: root.itemHeight
                color: Theme.inactiveColor
                radius: Theme.itemRadius
                onClicked: {
                  UpdateService.resetSelection();
                  root.close();
                }

                StyledText {
                  anchors.centerIn: parent
                  text: qsTr("Cancel")
                  font.bold: true
                  color: Theme.textContrast(cancelBtn.color)
                }
              }
            }
          }

          // View 1: Live Output
          ColumnLayout {
            spacing: 0

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: root.itemHeight * 2
              color: Theme.bgColor

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                StyledText {
                  Layout.fillWidth: true
                  text: {
                    const current = UpdateService.currentPackageIndex;
                    const total = UpdateService.totalPackagesToUpdate;
                    return total > 0 ? qsTr("Installing %1 of %2 packages...").arg(current).arg(total) : qsTr("Updating packages...");
                  }
                  font.bold: true
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 6
                  color: Theme.borderColor
                  radius: 3

                  Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: {
                      const total = UpdateService.totalPackagesToUpdate;
                      return total > 0 ? parent.width * (UpdateService.currentPackageIndex / total) : 0;
                    }
                    color: Theme.activeColor
                    radius: parent.radius
                    Behavior on width {
                      NumberAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.OutQuad
                      }
                    }
                  }
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 1
              color: Theme.borderColor
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              color: Qt.darker(Theme.bgColor, 1.05)

              ListView {
                id: outputListView
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                spacing: 2
                model: UpdateService.outputLines
                property bool userScrolledUp: false

                ScrollBar.vertical: ScrollBar {
                  policy: ScrollBar.AsNeeded
                  minimumSize: 0.1
                }

                onContentYChanged: {
                  if (!moving && !flicking)
                    return;
                  const atBottom = atYEnd || (contentHeight - contentY - height) < 10;
                  userScrolledUp = !atBottom;
                }

                onCountChanged: {
                  if (!userScrolledUp)
                    Qt.callLater(() => positionViewAtEnd());
                }

                delegate: Item {
                  id: outputDelegate
                  required property string modelData
                  width: ListView.view.width
                  height: lineText.height

                  Text {
                    id: lineText
                    width: parent.width
                    text: outputDelegate.modelData
                    font.family: "Monospace"
                    font.pixelSize: Theme.fontSize * 0.9
                    color: {
                      const line = outputDelegate.modelData.toLowerCase();
                      if (line.includes("error") || line.includes("failed"))
                        return Theme.critical;
                      if (line.includes("warning"))
                        return Theme.warning;
                      if (line.includes("installing") || line.includes("upgrading"))
                        return Theme.activeColor;
                      return Theme.textInactiveColor;
                    }
                    wrapMode: Text.Wrap
                  }
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 1
              color: Theme.borderColor
            }

            ClickableRect {
              id: cancelUpdateBtn
              Layout.fillWidth: true
              Layout.preferredHeight: root.itemHeight
              color: hovered ? Theme.onHoverColor : Theme.inactiveColor
              radius: 0
              onClicked: UpdateService.cancelUpdate()

              StyledText {
                anchors.centerIn: parent
                text: qsTr("Cancel Update")
                font.bold: true
                color: Theme.textContrast(cancelUpdateBtn.color)
              }
            }
          }

          // View 2: Completion/Error (condensed - removed duplicate code)
          Item {
            ColumnLayout {
              anchors.centerIn: parent
              spacing: 16
              width: parent.width * 0.8

              ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: UpdateService.updateState === UpdateService.status.Completed ? "✓" : "❌"
                  font.pixelSize: Theme.fontSize * 4
                  color: UpdateService.updateState === UpdateService.status.Completed ? Theme.activeColor : Theme.critical
                }

                StyledText {
                  Layout.alignment: Qt.AlignHCenter
                  text: {
                    if (UpdateService.updateState === UpdateService.status.Completed) {
                      const count = UpdateService.completedPackages.length;
                      return qsTr("%1 Package%2 Updated Successfully").arg(count).arg(count !== 1 ? "s" : "");
                    }
                    return qsTr("Update Failed");
                  }
                  font.pixelSize: Theme.fontSize * 1.5
                  font.bold: true
                }

                StyledText {
                  Layout.alignment: Qt.AlignHCenter
                  text: UpdateService.updateState === UpdateService.status.Error ? UpdateService.errorMessage : qsTr("All updates have been installed")
                  color: Theme.textInactiveColor
                  opacity: 0.8
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.Wrap
                  Layout.preferredWidth: parent.width
                }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                color: Qt.darker(Theme.bgColor, 1.05)
                radius: Theme.itemRadius
                border.color: Theme.borderColor
                border.width: 1
                visible: UpdateService.updateState === UpdateService.status.Error

                ScrollView {
                  anchors.fill: parent
                  anchors.margins: 8
                  clip: true

                  ListView {
                    model: UpdateService.outputLines.slice(-20)
                    spacing: 2

                    delegate: Item {
                      id: errorDelegate
                      required property string modelData
                      width: ListView.view.width
                      height: errorLineText.height

                      Text {
                        id: errorLineText
                        width: parent.width
                        text: errorDelegate.modelData
                        font.family: "Monospace"
                        font.pixelSize: Theme.fontSize * 0.85
                        color: {
                          const line = errorDelegate.modelData.toLowerCase();
                          if (line.includes("error") || line.includes("failed"))
                            return Theme.critical;
                          if (line.includes("warning"))
                            return Theme.warning;
                          return Theme.textInactiveColor;
                        }
                        wrapMode: Text.Wrap
                      }
                    }
                  }
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: root.itemHeight
                  color: retryMouse.containsMouse ? Qt.lighter(Theme.warning, 1.2) : Theme.warning
                  radius: Theme.itemRadius
                  visible: UpdateService.updateState === UpdateService.status.Error
                  Behavior on color {
                    ColorAnimation {
                      duration: Theme.animationDuration
                    }
                  }

                  StyledText {
                    anchors.centerIn: parent
                    text: qsTr("Retry")
                    font.bold: true
                    color: Theme.textContrast(parent.color)
                  }

                  MouseArea {
                    id: retryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      UpdateService.updateState = UpdateService.status.Idle;
                      UpdateService.executeUpdate();
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: root.itemHeight
                  color: closeMouse.containsMouse ? Theme.onHoverColor : Theme.activeColor
                  radius: Theme.itemRadius
                  Behavior on color {
                    ColorAnimation {
                      duration: Theme.animationDuration
                    }
                  }

                  StyledText {
                    anchors.centerIn: parent
                    text: qsTr("Close")
                    font.bold: true
                    color: Theme.textContrast(parent.color)
                  }

                  MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      UpdateService.updateState = UpdateService.status.Idle;
                      UpdateService.resetSelection();
                      root.close();
                    }
                  }
                }
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
        orientation: 1
        radius: Theme.panelRadius * 3
      }

      // Right inverse corner
      RoundCorner {
        anchors.left: panelBackground.right
        anchors.leftMargin: -1
        y: panelBackground.y
        color: Theme.bgColor
        orientation: 0
        radius: Theme.panelRadius * 3
      }
    }

    Connections {
      target: UpdateService
      function onUpdateStateChanged() {
        if (UpdateService.updateState === UpdateService.status.Completed) {
          root.close();
        }
      }
    }
  }

  component StyledText: Text {
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.textActiveColor
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
  }

  component ClickableRect: Rectangle {
    property alias hovered: mouseArea.containsMouse
    signal clicked
    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: parent.clicked()
    }
    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }
  }
}
