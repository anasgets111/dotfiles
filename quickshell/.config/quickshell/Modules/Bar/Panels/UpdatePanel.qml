pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Components
import qs.Config
import qs.Services.SystemInfo
import qs.Services.Utils

PanelContentBase {
  id: root

  property bool showCompletedLog: false
  readonly property bool showLog: UpdateService.isUpdating || UpdateService.isError || (UpdateService.isCompleted && showCompletedLog)
  readonly property real progress: UpdateService.totalPackagesToUpdate > 0 ? UpdateService.currentPackageIndex / UpdateService.totalPackagesToUpdate : 0

  function durationText(milliseconds: real): string {
    const seconds = Math.max(0, Math.round(milliseconds / 1000));
    const minutes = Math.floor(seconds / 60);
    return minutes > 0 ? qsTr("%1 min %2 sec").arg(minutes).arg(seconds % 60) : qsTr("%1 sec").arg(seconds);
  }
  function lastCheckText(): string {
    if (UpdateService.lastSuccessfulCheck <= 0)
      return qsTr("Never checked");
    return Qt.formatDateTime(new Date(UpdateService.lastSuccessfulCheck), "MMM d, h:mm AP");
  }
  function logColor(raw: string): color {
    const text = raw.toLowerCase();
    if (text.includes("[fail]") || text.includes("error") || text.includes("failed"))
      return Theme.critical;
    if (text.includes("warning") || text.includes("[skip]"))
      return Theme.warning;
    if (text.includes("downloading") || text.includes("retrieving"))
      return Theme.activeColor;
    if (text.includes("installing") || text.includes("upgrading") || /\(\s*\d+\/\d+\)/.test(text))
      return Theme.activeColor;
    if (text.includes("[ ok ]") || text.includes("complete") || text.includes("up to date"))
      return Theme.powerSaveColor;
    return raw.startsWith("▶") || raw.startsWith("::") || raw.startsWith("==>") ? Theme.textActiveColor : Theme.textInactiveColor;
  }
  function statusText(): string {
    if (UpdateService.isChecking)
      return qsTr("Checking…");
    if (UpdateService.isUpdating)
      return UpdateService.currentStep || qsTr("Preparing update…");
    if (UpdateService.isError)
      return qsTr("Update failed");
    if (UpdateService.isCompleted)
      return qsTr("Update complete");
    if (UpdateService.isStale && UpdateService.checkError)
      return qsTr("Check failed · results stale");
    return UpdateService.totalUpdates > 0 ? qsTr("%1 updates available").arg(UpdateService.totalUpdates) : qsTr("Up to date");
  }

  preferredHeight: mainLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: Theme.updatePanelWidth

  onIsOpenChanged: if (!isOpen)
    showCompletedLog = false

  ColumnLayout {
    id: mainLayout

    anchors.fill: parent
    anchors.margins: Theme.spacingMd
    spacing: Theme.spacingMd

    PanelCard {
      Layout.fillWidth: true
      tone: UpdateService.isError ? "error" : UpdateService.isStale && UpdateService.checkError ? "warning" : UpdateService.isCompleted ? "active" : "standard"

      ColumnLayout {
        width: parent?.width ?? 0
        spacing: Theme.spacingXs

        RowLayout {
          Layout.fillWidth: true

          OText {
            Layout.fillWidth: true
            bold: true
            font.pixelSize: Theme.fontLg
            text: root.statusText()
          }
          OText {
            color: Theme.textInactiveColor
            size: "xs"
            text: root.lastCheckText()
            visible: !UpdateService.isUpdating
          }
        }
        OText {
          Layout.fillWidth: true
          color: Theme.textInactiveColor
          size: "sm"
          text: UpdateService.isUpdating ? [UpdateService.currentPackage, UpdateService.progressDeterminate ? `${UpdateService.currentPackageIndex}/${UpdateService.totalPackagesToUpdate}` : ""].filter(Boolean).join(" · ") : UpdateService.isCompleted ? qsTr("%1 packages · %2 · %3 warnings%4").arg(UpdateService.completedPackageCount).arg(root.durationText(UpdateService.updateDurationMs)).arg(UpdateService.warningCount).arg(UpdateService.rebootRequired ? qsTr(" · Reboot required") : "") : UpdateService.isStale && UpdateService.checkError ? qsTr("Last successful result retained · %1").arg(UpdateService.checkError) : UpdateService.totalUpdates > 0 ? qsTr("%1 download · %2 packages").arg(Utils.fmtKib(UpdateService.totalDownloadSize)).arg(UpdateService.totalUpdates) : qsTr("No package updates available")
        }
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Theme.radiusSm
          color: Theme.borderColor
          radius: Theme.radiusXs
          visible: UpdateService.isUpdating && UpdateService.progressDeterminate

          Rectangle {
            color: Theme.activeColor
            height: parent.height
            radius: parent.radius
            width: parent.width * root.progress
            Behavior on width { NumberAnimation { duration: Theme.animationDuration } }
          }
        }
        RowLayout {
          spacing: Theme.spacingSm
          visible: UpdateService.isUpdating && !UpdateService.progressDeterminate

          OSpinner { running: visible }
          OText { color: Theme.textInactiveColor; size: "xs"; text: qsTr("Working…") }
        }
      }
    }

    PanelCard {
      Layout.fillWidth: true
      Layout.preferredHeight: Theme.itemHeight * Theme.updateTableVisibleRows + padding * 2
      visible: !root.showLog && !UpdateService.isCompleted

      Item {
        height: parent?.height ?? 0
        width: parent?.width ?? 0

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Theme.spacingSm
          visible: UpdateService.isChecking

          OSpinner { Layout.alignment: Qt.AlignHCenter; running: visible }
          OText { text: qsTr("Checking…") }
        }
        ListView {
          id: packageList

          anchors.fill: parent
          boundsBehavior: Flickable.StopAtBounds
          clip: true
          headerPositioning: ListView.OverlayHeader
          model: UpdateService.updatePackages.slice().sort((left, right) => left.name.localeCompare(right.name))
          visible: !UpdateService.isChecking && UpdateService.totalUpdates > 0

          header: Rectangle {
            width: packageList.width
            height: Theme.itemHeight
            color: Theme.bgCardHover
            z: 2

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Theme.spacingSm
              anchors.rightMargin: Theme.spacingSm
              OText { Layout.preferredWidth: Theme.updatePackageColumnWidth; bold: true; text: qsTr("Package") }
              OText { Layout.preferredWidth: Theme.updateOldVersionColumnWidth; bold: true; text: qsTr("Old Version") }
              OText { Layout.fillWidth: true; bold: true; text: qsTr("New Version") }
            }
          }
          delegate: Item {
            id: packageRow

            required property var modelData
            width: ListView.view.width
            height: Theme.itemHeight

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Theme.spacingSm
              anchors.rightMargin: Theme.spacingSm
              OText { Layout.preferredWidth: Theme.updatePackageColumnWidth; elide: Text.ElideRight; text: packageRow.modelData.name ?? "" }
              OText { Layout.preferredWidth: Theme.updateOldVersionColumnWidth; color: Theme.textInactiveColor; elide: Text.ElideRight; text: packageRow.modelData.oldVersion ?? "" }
              OText { Layout.fillWidth: true; color: Theme.activeColor; elide: Text.ElideRight; text: packageRow.modelData.newVersion ?? "" }
            }
          }
        }
        ColumnLayout {
          anchors.centerIn: parent
          spacing: Theme.spacingXs
          visible: !UpdateService.isChecking && UpdateService.totalUpdates === 0
          OText { Layout.alignment: Qt.AlignHCenter; color: Theme.powerSaveColor; font.pixelSize: Theme.fontXl; text: "󰄬" }
          OText { bold: true; text: qsTr("Up to date") }
          OText { color: Theme.textInactiveColor; size: "xs"; text: root.lastCheckText() }
        }
      }
    }

    PanelCard {
      Layout.fillWidth: true
      Layout.preferredHeight: Theme.itemHeight * Theme.updateLogVisibleRows + padding * 2
      tone: UpdateService.isError ? "error" : "standard"
      visible: root.showLog

      ColumnLayout {
        height: parent?.height ?? 0
        width: parent?.width ?? 0
        spacing: Theme.spacingSm

        OText {
          Layout.fillWidth: true
          color: Theme.critical
          text: UpdateService.errorMessage
          visible: UpdateService.isError
          wrapMode: Text.Wrap
        }
        ListView {
          id: logView

          property bool followOutput: true
          Layout.fillHeight: true
          Layout.fillWidth: true
          clip: true
          model: UpdateService.outputLines
          spacing: Theme.spacingXs

          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
          delegate: OText {
            required property var modelData
            width: ListView.view.width
            color: root.logColor(modelData)
            font.family: "Monospace"
            font.pixelSize: Theme.fontSm
            text: modelData
            wrapMode: Text.Wrap
          }
          onContentYChanged: if (moving || flicking)
            followOutput = atYEnd
          onCountChanged: if (followOutput)
            Qt.callLater(positionViewAtEnd)
        }
      }
    }

    PanelCard {
      Layout.fillWidth: true
      visible: UpdateService.isCompleted && !root.showCompletedLog

      RowLayout {
        width: parent?.width ?? 0
        OText {
          Layout.fillWidth: true
          color: Theme.textInactiveColor
          text: UpdateService.rebootRequired ? qsTr("Update finished. A reboot is required.") : qsTr("Update finished successfully.")
        }
        OButton { text: qsTr("View log"); variant: "secondary"; onClicked: root.showCompletedLog = true }
      }
    }

    PanelCard {
      Layout.fillWidth: true

      ColumnLayout {
        width: parent?.width ?? 0
        spacing: Theme.spacingSm

        OButton {
          Layout.fillWidth: true
          isEnabled: UpdateService.ready && !UpdateService.busy
          text: qsTr("Check")
          variant: "secondary"
          visible: UpdateService.isStale && !UpdateService.isUpdating
          onClicked: UpdateService.doPoll()
        }
        OButton {
          Layout.fillWidth: true
          isEnabled: UpdateService.ready && !UpdateService.busy && (UpdateService.totalUpdates > 0 || UpdateService.isError)
          text: UpdateService.isError ? qsTr("Retry") : qsTr("Update")
          visible: (UpdateService.totalUpdates > 0 || UpdateService.isError) && !UpdateService.isCompleted
          onClicked: UpdateService.executeUpdate()
        }
        OButton {
          Layout.fillWidth: true
          text: qsTr("Close")
          variant: "secondary"
          visible: UpdateService.isCompleted || UpdateService.isError
          onClicked: {
            UpdateService.dismissResult();
            root.closeRequested();
          }
        }
      }
    }
  }
}
