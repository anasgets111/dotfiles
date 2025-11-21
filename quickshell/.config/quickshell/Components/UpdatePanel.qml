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
  readonly property int itemHeight: Theme.itemHeight
  readonly property int maxItems: 10
  readonly property int padding: 8
  readonly property int viewIndex: {
    const s = UpdateService.updateState;
    return s === UpdateService.status.Idle ? 0 : s === UpdateService.status.Updating ? 1 : 2;
  }

  needsKeyboardFocus: root.viewIndex === 0 || root.viewIndex === 2
  panelNamespace: "obelisk-update-panel"
  panelWidth: 500

  Connections {
    function onUpdateStateChanged() {
      if (UpdateService.updateState === UpdateService.status.Completed)
        root.close();
    }

    target: UpdateService
  }

  FocusScope {
    focus: root.isOpen
    implicitHeight: stack.implicitHeight + root.padding * 2
    width: parent.width

    StackLayout {
      id: stack

      currentIndex: root.viewIndex
      width: parent.width - root.padding * 2
      x: root.padding
      y: root.padding

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

            OText {
              Layout.preferredWidth: 160
              color: Theme.textContrast(root.headerColor)
              font.bold: true
              text: qsTr("Package")
            }

            OText {
              Layout.preferredWidth: 120
              color: Theme.textContrast(root.headerColor)
              font.bold: true
              text: qsTr("Old Version")
            }

            OText {
              Layout.preferredWidth: 120
              color: Theme.textContrast(root.headerColor)
              font.bold: true
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
          spacing: 2
          visible: UpdateService.totalUpdates > 0

          ScrollBar.vertical: ScrollBar {
            policy: packageList.contentHeight > packageList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 8
          }
          delegate: Rectangle {
            id: packageRow

            required property var modelData
            readonly property string newVer: packageRow.modelData.newVersion || ""
            readonly property string oldVer: packageRow.modelData.oldVersion || ""
            readonly property string pkgName: packageRow.modelData.name || ""

            color: packageHover.containsMouse ? Qt.lighter(Theme.bgColor, 1.47) : Theme.bgColor
            height: root.itemHeight
            radius: Theme.itemRadius * 0.5
            width: ListView.view.width

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration * 0.7
              }
            }

            MouseArea {
              id: packageHover

              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: root.padding
              anchors.rightMargin: root.padding
              spacing: 8

              OText {
                Layout.preferredWidth: 160
                elide: Text.ElideRight
                text: packageRow.pkgName
              }

              OText {
                Layout.preferredWidth: 120
                color: Theme.textInactiveColor
                elide: Text.ElideRight
                text: packageRow.oldVer
              }

              OText {
                Layout.preferredWidth: 120
                color: Theme.activeColor
                elide: Text.ElideRight
                text: packageRow.newVer
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: root.itemHeight * 2
          color: "transparent"
          visible: UpdateService.totalUpdates === 0

          OText {
            anchors.centerIn: parent
            color: Theme.textInactiveColor
            text: qsTr("No updates available")
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: root.itemHeight * 0.6
          color: "transparent"
          visible: UpdateService.totalUpdates > 0

          RowLayout {
            anchors.centerIn: parent
            spacing: 4

            OText {
              color: Theme.textInactiveColor
              opacity: 0.7
              text: "󰇚"
            }

            OText {
              opacity: 0.8
              sizeMultiplier: 0.9
              text: qsTr("Total download: %1").arg(SystemInfoService.fmtKib(UpdateService.totalDownloadSize))
              useActiveColor: false
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          OButton {
            Layout.fillWidth: true
            bgColor: Theme.activeColor
            isEnabled: UpdateService.totalUpdates > 0
            text: qsTr("Update Now")

            onClicked: {
              UpdateService.executeUpdate();
            }
          }

          OButton {
            Layout.fillWidth: true
            bgColor: Theme.inactiveColor
            text: qsTr("Cancel")

            onClicked: {
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
              font.bold: true
              text: {
                const cur = UpdateService.currentPackageIndex;
                const tot = UpdateService.totalPackagesToUpdate;
                return tot > 0 ? qsTr("Installing %1 of %2 packages...").arg(cur).arg(tot) : qsTr("Updating packages...");
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 6
              color: Theme.borderColor
              radius: 3

              Rectangle {
                color: Theme.activeColor
                height: parent.height
                radius: parent.radius
                width: {
                  const tot = UpdateService.totalPackagesToUpdate;
                  return tot > 0 ? parent.width * (UpdateService.currentPackageIndex / tot) : 0;
                }

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
          Layout.fillHeight: true
          Layout.fillWidth: true
          color: Qt.darker(Theme.bgColor, 1.05)

          ListView {
            id: outputView

            property bool userScrolled: false

            anchors.fill: parent
            anchors.margins: 8
            clip: true
            model: UpdateService.outputLines
            spacing: 2

            ScrollBar.vertical: ScrollBar {
              minimumSize: 0.1
              policy: ScrollBar.AsNeeded
            }
            delegate: Text {
              id: outputLine

              required property var modelData

              color: {
                const line = outputLine.text.toLowerCase();
                return line.includes("error") || line.includes("failed") ? Theme.critical : line.includes("warning") ? Theme.warning : line.includes("installing") || line.includes("upgrading") ? Theme.activeColor : Theme.textInactiveColor;
              }
              font.family: "Monospace"
              font.pixelSize: Theme.fontSize * 0.9
              text: outputLine.modelData.text || outputLine.modelData
              width: ListView.view.width
              wrapMode: Text.Wrap
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

        readonly property color accentColor: isSuccess ? Theme.activeColor : Theme.critical
        readonly property bool isError: UpdateService.updateState === UpdateService.status.Error
        readonly property bool isSuccess: UpdateService.updateState === UpdateService.status.Completed

        Layout.fillWidth: true
        Layout.margins: root.padding
        spacing: 20

        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          Layout.fillWidth: true
          Layout.maximumWidth: Math.min(root.panelWidth - root.padding * 2, 460)
          spacing: 16

          Rectangle {
            Layout.preferredHeight: Layout.preferredWidth
            Layout.preferredWidth: Theme.itemHeight * 1.6
            border.color: completionView.accentColor
            border.width: 1
            color: Qt.rgba(completionView.accentColor.r, completionView.accentColor.g, completionView.accentColor.b, 0.12)
            radius: width / 2

            Text {
              anchors.centerIn: parent
              color: completionView.accentColor
              font.pixelSize: Theme.fontSize * 3.2
              text: completionView.isSuccess ? "✓" : "❌"
            }
          }

          ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            spacing: 6

            OText {
              Layout.fillWidth: true
              font.bold: true
              horizontalAlignment: Text.AlignLeft
              sizeMultiplier: 1.5
              text: {
                if (completionView.isSuccess) {
                  const cnt = UpdateService.completedPackages.length;
                  return qsTr("%1 Package%2 Updated Successfully").arg(cnt).arg(cnt !== 1 ? "s" : "");
                }
                return qsTr("Update Failed");
              }
            }

            OText {
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignLeft
              opacity: 0.85
              text: completionView.isError ? UpdateService.errorMessage : qsTr("All updates have been installed")
              useActiveColor: false
              wrapMode: Text.Wrap
            }
          }
        }

        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          Layout.fillWidth: true
          Layout.maximumWidth: Math.min(root.panelWidth - root.padding * 2, 520)
          Layout.preferredHeight: 160
          border.color: Theme.borderColor
          border.width: 1
          color: Qt.darker(Theme.bgColor, 1.05)
          radius: Theme.itemRadius
          visible: completionView.isError

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

                color: {
                  const line = errorLine.text.toLowerCase();
                  return line.includes("error") || line.includes("failed") ? Theme.critical : line.includes("warning") ? Theme.warning : Theme.textInactiveColor;
                }
                font.family: "Monospace"
                font.pixelSize: Theme.fontSize * 0.85
                text: errorLine.modelData.text || errorLine.modelData
                width: ListView.view.width
                wrapMode: Text.Wrap
              }
            }
          }
        }

        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          Layout.fillWidth: true
          Layout.maximumWidth: Math.min(root.panelWidth - root.padding * 2, 460)
          spacing: 8

          OButton {
            Layout.fillWidth: true
            bgColor: Theme.warning
            hoverColor: Qt.lighter(Theme.warning, 1.2)
            text: qsTr("Retry")
            visible: completionView.isError

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
              UpdateService.closeAllNotifications();
              root.close();
            }
          }
        }
      }
    }
  }
}
