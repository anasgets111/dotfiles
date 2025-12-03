pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Config
import qs.Components
import qs.Services.SystemInfo

OPanel {
  id: root

  readonly property color headerColor: Qt.lighter(Theme.bgColor, 1.74)
  readonly property bool isIdle: UpdateService.updateState === UpdateService.status.Idle
  readonly property bool isUpdating: UpdateService.updateState === UpdateService.status.Updating
  readonly property int itemHeight: Theme.itemHeight
  readonly property int maxItems: 10
  readonly property int pad: Theme.spacingSm

  maxHeight: 900
  needsKeyboardFocus: true
  panelNamespace: "obelisk-update-panel"
  panelWidth: 500

  FocusScope {
    focus: root.isOpen
    implicitHeight: (root.isIdle ? packageView.implicitHeight : outputView.implicitHeight) + root.pad * 2
    width: parent.width

    StackLayout {
      id: stack

      currentIndex: root.isIdle ? 0 : 1
      height: root.isIdle ? packageView.implicitHeight : outputView.implicitHeight
      width: parent.width - root.pad * 2
      x: root.pad
      y: root.pad

      // View 0: Package List
      ColumnLayout {
        id: packageView

        spacing: Theme.spacingXs

        // Header row
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: root.itemHeight
          color: root.headerColor
          radius: Theme.itemRadius

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.pad
            anchors.rightMargin: root.pad
            spacing: Theme.spacingSm

            OText {
              Layout.preferredWidth: 160
              bold: true
              color: Theme.textContrast(root.headerColor)
              text: qsTr("Package")
            }

            OText {
              Layout.preferredWidth: 120
              bold: true
              color: Theme.textContrast(root.headerColor)
              text: qsTr("Old Version")
            }

            OText {
              Layout.preferredWidth: 120
              bold: true
              color: Theme.textContrast(root.headerColor)
              text: qsTr("New Version")
            }
          }
        }

        ListView {
          id: packageList

          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(contentHeight, root.maxItems * root.itemHeight)
          clip: true
          interactive: contentHeight > height
          model: UpdateService.updatePackages
          spacing: Theme.spacingXs / 2
          visible: UpdateService.totalUpdates > 0

          ScrollBar.vertical: ScrollBar {
            policy: packageList.contentHeight > packageList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: Theme.scrollBarWidth
          }
          delegate: Rectangle {
            id: pkgRow

            required property var modelData

            color: pkgHover.containsMouse ? Theme.bgElevatedHover : Theme.bgColor
            height: root.itemHeight
            radius: Theme.itemRadius * 0.5
            width: ListView.view.width

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration * 0.7
              }
            }

            MouseArea {
              id: pkgHover

              anchors.fill: parent
              hoverEnabled: true
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: root.pad
              anchors.rightMargin: root.pad
              spacing: Theme.spacingSm

              OText {
                Layout.preferredWidth: 160
                elide: Text.ElideRight
                text: pkgRow.modelData.name ?? ""
              }

              OText {
                Layout.preferredWidth: 120
                color: Theme.textInactiveColor
                elide: Text.ElideRight
                text: pkgRow.modelData.oldVersion ?? ""
              }

              OText {
                Layout.preferredWidth: 120
                color: Theme.activeColor
                elide: Text.ElideRight
                text: pkgRow.modelData.newVersion ?? ""
              }
            }
          }
        }

        OText {
          Layout.fillWidth: true
          Layout.preferredHeight: root.itemHeight * 2
          color: Theme.textInactiveColor
          horizontalAlignment: Text.AlignHCenter
          text: qsTr("No updates available")
          verticalAlignment: Text.AlignVCenter
          visible: UpdateService.totalUpdates === 0
        }

        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          Layout.topMargin: Theme.spacingXs
          spacing: Theme.spacingXs
          visible: UpdateService.totalUpdates > 0

          OText {
            color: Theme.textInactiveColor
            opacity: 0.7
            text: "󰇚"
          }

          OText {
            opacity: 0.8
            size: "sm"
            text: qsTr("Total download: %1").arg(SystemInfoService.fmtKib(UpdateService.totalDownloadSize))
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: Theme.spacingSm
          spacing: Theme.spacingSm

          OButton {
            Layout.fillWidth: true
            bgColor: Theme.activeColor
            isEnabled: UpdateService.totalUpdates > 0
            text: qsTr("Update Now")

            onClicked: UpdateService.executeUpdate()
          }

          OButton {
            Layout.fillWidth: true
            bgColor: Theme.inactiveColor
            text: qsTr("Cancel")

            onClicked: root.close()
          }
        }
      }

      // View 1: Live Output
      ColumnLayout {
        id: outputView

        ColumnLayout {
          Layout.fillWidth: true
          Layout.margins: Theme.spacingSm
          spacing: Theme.spacingXs

          OText {
            bold: true
            text: UpdateService.totalPackagesToUpdate > 0 ? qsTr("Installing %1 of %2 packages...").arg(UpdateService.currentPackageIndex).arg(UpdateService.totalPackagesToUpdate) : qsTr("Updating packages...")
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.radiusSm
            color: Theme.borderColor
            radius: Theme.radiusXs

            Rectangle {
              color: Theme.activeColor
              height: parent.height
              radius: parent.radius
              width: UpdateService.totalPackagesToUpdate > 0 ? parent.width * (UpdateService.currentPackageIndex / UpdateService.totalPackagesToUpdate) : 0

              Behavior on width {
                NumberAnimation {
                  duration: Theme.animationDuration
                }
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          color: Theme.borderColor
          height: 1
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Theme.itemHeight * 15
          color: Qt.darker(Theme.bgColor, 1.05)

          ListView {
            id: logView

            property bool userScrolled: false

            anchors.fill: parent
            anchors.margins: Theme.spacingSm
            clip: true
            model: UpdateService.outputLines
            spacing: Theme.spacingXs / 2

            ScrollBar.vertical: ScrollBar {
              minimumSize: 0.1
              policy: ScrollBar.AsNeeded
            }
            delegate: Text {
              required property var modelData

              color: {
                const t = text.toLowerCase();
                return t.includes("error") || t.includes("failed") ? Theme.critical : t.includes("warning") ? Theme.warning : t.includes("installing") || t.includes("upgrading") ? Theme.activeColor : Theme.textInactiveColor;
              }
              font.family: "Monospace"
              font.pixelSize: Theme.fontSize * 0.9
              text: modelData.text ?? modelData
              width: ListView.view.width
              wrapMode: Text.Wrap
            }

            onContentYChanged: {
              if (moving || flicking) {
                userScrolled = !atYEnd && (contentHeight - contentY - height) >= 10;
              }
            }
            onCountChanged: if (!userScrolled)
              Qt.callLater(positionViewAtEnd)
          }
        }

        Rectangle {
          Layout.fillWidth: true
          color: Theme.borderColor
          height: 1
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: Theme.spacingSm
          spacing: Theme.spacingSm

          OButton {
            Layout.fillWidth: true
            bgColor: Theme.warning
            text: qsTr("Retry")
            visible: UpdateService.updateState === UpdateService.status.Error

            onClicked: {
              UpdateService.updateState = UpdateService.status.Idle;
              UpdateService.executeUpdate();
            }
          }

          OButton {
            Layout.fillWidth: true
            bgColor: root.isUpdating ? Theme.inactiveColor : Theme.activeColor
            text: root.isUpdating ? qsTr("Cancel Update") : qsTr("Close")

            onClicked: {
              if (root.isUpdating) {
                UpdateService.cancelUpdate();
              } else {
                UpdateService.updateState = UpdateService.status.Idle;
                UpdateService.closeAllNotifications();
                root.close();
              }
            }
          }
        }
      }
    }
  }
}
