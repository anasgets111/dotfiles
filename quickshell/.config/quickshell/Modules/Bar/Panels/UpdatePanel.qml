pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Components
import qs.Config
import qs.Services.SystemInfo
import qs.Services.Utils

PanelContentBase {
  id: root

  readonly property bool hasUpdates: UpdateService.ready && UpdateService.totalUpdates > 0
  readonly property color headerColor: Theme.bgCardHover
  readonly property bool isError: UpdateService.isError
  readonly property bool isIdle: UpdateService.isIdle
  readonly property bool isPackageStep: UpdateService.isSystemPackageStep
  readonly property bool isUpdating: UpdateService.isUpdating
  readonly property int itemHeight: Theme.itemHeight
  readonly property int maxItems: 10
  readonly property int pad: Theme.spacingSm
  readonly property real progress: UpdateService.totalPackagesToUpdate > 0 ? UpdateService.currentPackageIndex / UpdateService.totalPackagesToUpdate : 0

  function logColor(raw) {
    const t = raw.toLowerCase();
    if (t.includes("[fail]") || t.includes("error") || t.includes("failed"))
      return Theme.critical;
    if (t.includes("[skip]") || t.includes("warning"))
      return Theme.warning;
    if (t.includes("[ ok ]") || t.includes("successful") || t.includes("done.") || t.includes("is up to date") || t.includes("nothing to do") || t.includes("no packages need"))
      return Theme.powerSaveColor;
    if (raw.startsWith("▶") || raw.startsWith("::") || (raw.startsWith("==>") && !t.includes("warning")))
      return Theme.textActiveColor;
    if (/\(\d+\/\d+\)/.test(raw) || t.includes("installing") || t.includes("upgrading"))
      return Theme.activeColor;
    if (t.includes("-> running") || t.includes("build hook"))
      return Theme.activeColor;
    return Theme.textInactiveColor;
  }
  function updateStatusText(): string {
    if (!root.isUpdating) {
      if (root.isError)
        return UpdateService.errorMessage || qsTr("Update failed");
      return qsTr("Update complete");
    }
    if (root.isPackageStep && UpdateService.totalPackagesToUpdate > 0)
      return qsTr("Installing %1 of %2 system packages...").arg(UpdateService.currentPackageIndex).arg(UpdateService.totalPackagesToUpdate);
    return UpdateService.currentStep ? qsTr("Running %1...").arg(UpdateService.currentStep) : qsTr("Updating system and developer tooling...");
  }

  preferredHeight: contentScope.implicitHeight + root.pad * 2
  preferredWidth: 500

  FocusScope {
    id: contentScope

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
          visible: root.hasUpdates

          ScrollBar.vertical: ScrollBar {
            policy: packageList.contentHeight > packageList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: Theme.scrollBarWidth
          }
          delegate: Rectangle {
            id: pkgRow

            required property var modelData

            color: pkgHover.containsMouse ? Theme.bgCardHover : Theme.bgCard
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
          text: UpdateService.ready ? qsTr("No system package updates available") : qsTr("Update service unavailable")
          verticalAlignment: Text.AlignVCenter
          visible: !root.hasUpdates
        }
        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          Layout.topMargin: Theme.spacingXs
          spacing: Theme.spacingXs
          visible: root.hasUpdates

          OText {
            color: Theme.textInactiveColor
            opacity: 0.7
            text: "󰇚"
          }
          OText {
            opacity: 0.8
            size: "sm"
            text: qsTr("Total download: %1").arg(Utils.fmtKib(UpdateService.totalDownloadSize))
          }
        }
        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: Theme.spacingSm
          spacing: Theme.spacingSm

          OButton {
            Layout.fillWidth: true
            bgColor: Theme.activeColor
            isEnabled: UpdateService.ready && !UpdateService.busy
            text: qsTr("Update All")

            onClicked: UpdateService.executeUpdate()
          }
          OButton {
            Layout.fillWidth: true
            bgColor: Theme.inactiveColor
            text: qsTr("Cancel")

            onClicked: root.closeRequested()
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
            text: root.updateStatusText()
          }
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.radiusSm
            color: Theme.borderColor
            radius: Theme.radiusXs
            visible: root.isPackageStep && UpdateService.totalPackagesToUpdate > 0

            Rectangle {
              color: Theme.activeColor
              height: parent.height
              radius: parent.radius
              width: parent.width * root.progress

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
          Layout.preferredHeight: 1
          color: Theme.borderColor
        }
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Theme.itemHeight * 15
          color: Theme.bgInput

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

              color: root.logColor(text)
              font.family: "Monospace"
              font.pixelSize: Theme.fontSize * 0.9
              text: modelData
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
          Layout.preferredHeight: 1
          color: Theme.borderColor
        }
        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: Theme.spacingSm
          spacing: Theme.spacingSm

          OButton {
            Layout.fillWidth: true
            bgColor: Theme.warning
            text: qsTr("Retry")
            visible: root.isError

            onClicked: UpdateService.executeUpdate()
          }
          OButton {
            Layout.fillWidth: true
            bgColor: root.isUpdating ? Theme.inactiveColor : Theme.activeColor
            text: root.isUpdating ? qsTr("Cancel Update") : qsTr("Close")

            onClicked: {
              if (root.isUpdating) {
                UpdateService.cancelUpdate();
              } else {
                UpdateService.dismissResult();
                root.closeRequested();
              }
            }
          }
        }
      }
    }
  }
}
