pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Config
import qs.Components
import qs.Services.SystemInfo

OPanel {
  id: root
  panelNamespace: "obelisk-update-panel"

  readonly property int maxItems: 10
  readonly property int itemHeight: Theme.itemHeight
  readonly property int padding: 8
  readonly property color headerColor: Qt.lighter(Theme.bgColor, 1.74)
  readonly property int viewIndex: {
    const s = UpdateService.updateState;
    return s === UpdateService.status.Idle ? 0 : s === UpdateService.status.Updating ? 1 : 2;
  }

  panelWidth: 500
  needsKeyboardFocus: root.viewIndex === 0 || root.viewIndex === 2

  Connections {
    target: UpdateService
    function onUpdateStateChanged() {
      if (UpdateService.updateState === UpdateService.status.Completed)
        root.close();
    }
  }

  FocusScope {
    width: parent.width
    implicitHeight: stack.implicitHeight + root.padding * 2
    focus: root.isOpen

    StackLayout {
      id: stack
      width: parent.width - root.padding * 2
      x: root.padding
      y: root.padding
      currentIndex: root.viewIndex

      // View 0: Package List
      ColumnLayout {
        spacing: 4

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: root.itemHeight
          color: root.headerColor
          radius: Theme.itemRadius

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.padding
            anchors.rightMargin: root.padding
            spacing: 8

            OCheckbox {
              Layout.preferredWidth: root.itemHeight * 0.6
              Layout.preferredHeight: root.itemHeight * 0.6
              checked: UpdateService.selectAll
              onClicked: UpdateService.toggleSelectAll()
            }

            OText {
              Layout.preferredWidth: 160
              text: qsTr("Package")
              font.bold: true
              color: Theme.textContrast(root.headerColor)
            }
            OText {
              Layout.preferredWidth: 120
              text: qsTr("Old Version")
              font.bold: true
              color: Theme.textContrast(root.headerColor)
            }
            OText {
              Layout.preferredWidth: 120
              text: qsTr("New Version")
              font.bold: true
              color: Theme.textContrast(root.headerColor)
            }
          }
        }

        ListView {
          id: packageList
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(contentHeight, root.maxItems * root.itemHeight)
          spacing: 2
          interactive: contentHeight > height
          clip: true
          model: UpdateService.updatePackages

          ScrollBar.vertical: ScrollBar {
            policy: packageList.contentHeight > packageList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 8
          }

          delegate: Rectangle {
            id: packageRow
            required property var modelData

            readonly property string pkgName: packageRow.modelData.name || ""
            readonly property string oldVer: packageRow.modelData.oldVersion || ""
            readonly property string newVer: packageRow.modelData.newVersion || ""

            width: ListView.view.width
            height: root.itemHeight
            color: packageHover.containsMouse ? Qt.lighter(Theme.bgColor, 1.47) : Theme.bgColor
            radius: Theme.itemRadius * 0.5

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration * 0.7
              }
            }

            MouseArea {
              id: packageHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: UpdateService.togglePackage(packageRow.pkgName)
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: root.padding
              anchors.rightMargin: root.padding
              spacing: 8

              OCheckbox {
                Layout.preferredWidth: root.itemHeight * 0.6
                Layout.preferredHeight: root.itemHeight * 0.6
                checked: UpdateService.selectedPackages[packageRow.pkgName] || false
                onClicked: UpdateService.togglePackage(packageRow.pkgName)
              }

              OText {
                Layout.preferredWidth: 160
                text: packageRow.pkgName
                elide: Text.ElideRight
              }

              OText {
                Layout.preferredWidth: 120
                text: packageRow.oldVer
                color: Theme.textInactiveColor
                elide: Text.ElideRight
              }

              OText {
                Layout.preferredWidth: 120
                text: packageRow.newVer
                color: Theme.activeColor
                elide: Text.ElideRight
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

            OText {
              text: "󰇚"
              color: Theme.textInactiveColor
              opacity: 0.7
            }
            OText {
              text: qsTr("Total download: %1").arg(SystemInfoService.fmtKib(UpdateService.totalDownloadSize))
              sizeMultiplier: 0.9
              useActiveColor: false
              opacity: 0.8
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          OButton {
            Layout.fillWidth: true
            readonly property bool hasSelection: UpdateService.selectedCount > 0
            bgColor: hasSelection ? Theme.activeColor : Theme.disabledColor
            isEnabled: hasSelection
            text: hasSelection ? qsTr("Update Selected (%1)").arg(UpdateService.selectedCount) : qsTr("Select packages")
            onClicked: UpdateService.executeUpdate()
          }

          OButton {
            Layout.fillWidth: true
            bgColor: Theme.activeColor
            text: qsTr("Update All")
            onClicked: {
              UpdateService.resetSelection();
              UpdateService.executeUpdate();
            }
          }

          OButton {
            Layout.fillWidth: true
            bgColor: Theme.inactiveColor
            text: qsTr("Cancel")
            onClicked: {
              UpdateService.resetSelection();
              root.close();
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

            OText {
              text: {
                const cur = UpdateService.currentPackageIndex;
                const tot = UpdateService.totalPackagesToUpdate;
                return tot > 0 ? qsTr("Installing %1 of %2 packages...").arg(cur).arg(tot) : qsTr("Updating packages...");
              }
              font.bold: true
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 6
              color: Theme.borderColor
              radius: 3

              Rectangle {
                width: {
                  const tot = UpdateService.totalPackagesToUpdate;
                  return tot > 0 ? parent.width * (UpdateService.currentPackageIndex / tot) : 0;
                }
                height: parent.height
                color: Theme.activeColor
                radius: parent.radius
                Behavior on width {
                  NumberAnimation {
                    duration: Theme.animationDuration
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
            id: outputView
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            spacing: 2
            model: UpdateService.outputLines
            property bool userScrolled: false

            ScrollBar.vertical: ScrollBar {
              policy: ScrollBar.AsNeeded
              minimumSize: 0.1
            }

            onContentYChanged: {
              if (outputView.moving || outputView.flicking) {
                const atBottom = outputView.atYEnd || (outputView.contentHeight - outputView.contentY - outputView.height) < 10;
                outputView.userScrolled = !atBottom;
              }
            }

            onCountChanged: {
              if (!outputView.userScrolled)
                Qt.callLater(() => outputView.positionViewAtEnd());
            }

            delegate: Text {
              id: outputLine
              required property var modelData

              width: ListView.view.width
              text: outputLine.modelData.text || outputLine.modelData
              font.family: "Monospace"
              font.pixelSize: Theme.fontSize * 0.9
              color: {
                const line = outputLine.text.toLowerCase();
                return line.includes("error") || line.includes("failed") ? Theme.critical : line.includes("warning") ? Theme.warning : line.includes("installing") || line.includes("upgrading") ? Theme.activeColor : Theme.textInactiveColor;
              }
              wrapMode: Text.Wrap
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: Theme.borderColor
        }

        OButton {
          Layout.fillWidth: true
          bgColor: Theme.inactiveColor
          hoverColor: Theme.onHoverColor
          text: qsTr("Cancel Update")
          onClicked: UpdateService.cancelUpdate()
        }
      }

      // View 2: Completion/Error
      ColumnLayout {
        id: completionView
        readonly property bool isSuccess: UpdateService.updateState === UpdateService.status.Completed
        readonly property bool isError: UpdateService.updateState === UpdateService.status.Error
        readonly property color accentColor: isSuccess ? Theme.activeColor : Theme.critical

        Layout.fillWidth: true
        Layout.margins: root.padding
        spacing: 20

        RowLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignHCenter
          Layout.maximumWidth: Math.min(root.panelWidth - root.padding * 2, 460)
          spacing: 16

          Rectangle {
            Layout.preferredWidth: Theme.itemHeight * 1.6
            Layout.preferredHeight: Layout.preferredWidth
            radius: width / 2
            color: Qt.rgba(completionView.accentColor.r, completionView.accentColor.g, completionView.accentColor.b, 0.12)
            border.color: completionView.accentColor
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: completionView.isSuccess ? "✓" : "❌"
              font.pixelSize: Theme.fontSize * 3.2
              color: completionView.accentColor
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            OText {
              Layout.fillWidth: true
              text: {
                if (completionView.isSuccess) {
                  const cnt = UpdateService.completedPackages.length;
                  return qsTr("%1 Package%2 Updated Successfully").arg(cnt).arg(cnt !== 1 ? "s" : "");
                }
                return qsTr("Update Failed");
              }
              sizeMultiplier: 1.5
              font.bold: true
              horizontalAlignment: Text.AlignLeft
            }

            OText {
              Layout.fillWidth: true
              text: completionView.isError ? UpdateService.errorMessage : qsTr("All updates have been installed")
              useActiveColor: false
              opacity: 0.85
              horizontalAlignment: Text.AlignLeft
              wrapMode: Text.Wrap
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignHCenter
          Layout.maximumWidth: Math.min(root.panelWidth - root.padding * 2, 520)
          Layout.preferredHeight: 160
          visible: completionView.isError
          color: Qt.darker(Theme.bgColor, 1.05)
          radius: Theme.itemRadius
          border.color: Theme.borderColor
          border.width: 1

          ScrollView {
            anchors.fill: parent
            anchors.margins: 8
            clip: true

            ListView {
              model: UpdateService.outputLines.slice(-20)
              spacing: 2

              delegate: Text {
                id: errorLine
                required property var modelData

                width: ListView.view.width
                text: errorLine.modelData.text || errorLine.modelData
                font.family: "Monospace"
                font.pixelSize: Theme.fontSize * 0.85
                color: {
                  const line = errorLine.text.toLowerCase();
                  return line.includes("error") || line.includes("failed") ? Theme.critical : line.includes("warning") ? Theme.warning : Theme.textInactiveColor;
                }
                wrapMode: Text.Wrap
              }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignHCenter
          Layout.maximumWidth: Math.min(root.panelWidth - root.padding * 2, 460)
          spacing: 8

          OButton {
            Layout.fillWidth: true
            bgColor: Theme.warning
            hoverColor: Qt.lighter(Theme.warning, 1.2)
            visible: completionView.isError
            text: qsTr("Retry")
            onClicked: {
              UpdateService.updateState = UpdateService.status.Idle;
              UpdateService.executeUpdate();
            }
          }

          OButton {
            Layout.fillWidth: true
            bgColor: Theme.activeColor
            text: qsTr("Close")
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
