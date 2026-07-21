pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.Config
import qs.Services.SystemInfo
import qs.Services.Utils

Item {
  id: root

  property bool _polling: false
  property bool active: false
  property bool expanded: false
  readonly property real storageProgress: {
    let used = 0;
    let total = 0;
    for (const disk of SystemInfoService.storageDisks) {
      used += disk.usedKib;
      total += disk.totalKib;
    }
    return total > 0 ? used / total : 0;
  }

  function formatDuration(rawSeconds: string): string {
    const totalMinutes = Math.floor((parseInt(rawSeconds, 10) || 0) / 60);
    const days = Math.floor(totalMinutes / 1440);
    const hours = Math.floor((totalMinutes % 1440) / 60);
    const minutes = totalMinutes % 60;
    return days > 0 ? qsTr("%1d %2h").arg(days).arg(hours) : hours > 0 ? qsTr("%1h %2m").arg(hours).arg(minutes) : qsTr("%1m").arg(minutes);
  }
  function statusColor(progress: real, fallback: color): color {
    return progress >= 0.9 ? Theme.critical : progress >= 0.75 ? Theme.warning : fallback;
  }
  function syncPolling(): void {
    const shouldPoll = active;
    if (shouldPoll === _polling)
      return;
    _polling = shouldPoll;
    SystemInfoService.refCount = Math.max(0, SystemInfoService.refCount + (shouldPoll ? 1 : -1));
  }

  implicitHeight: layout.implicitHeight

  Component.onCompleted: syncPolling()
  Component.onDestruction: {
    if (_polling)
      SystemInfoService.refCount = Math.max(0, SystemInfoService.refCount - 1);
  }
  onActiveChanged: syncPolling()

  ColumnLayout {
    id: layout

    anchors.left: parent.left
    anchors.right: parent.right
    spacing: Theme.spacingSm

    OButton {
      id: expandButton

      Layout.fillWidth: true
      Layout.preferredHeight: Theme.itemHeight
      bgColor: root.expanded ? Theme.activeColor : Theme.bgCard

      onClicked: root.expanded = !root.expanded

      RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: Theme.itemRadius
        anchors.right: parent.right
        anchors.rightMargin: Theme.itemRadius
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingSm

        OText {
          bold: true
          color: expandButton.textColor
          text: qsTr("System")
        }
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: summaryRow.implicitHeight

          OText {
            anchors.right: parent.right
            color: Qt.alpha(expandButton.textColor, 0.7)
            size: "sm"
            text: qsTr("live")
            visible: root.expanded
          }
          RowLayout {
            id: summaryRow

            anchors.right: parent.right
            spacing: Theme.spacingSm
            visible: !root.expanded

            OText {
              bold: true
              color: root.statusColor(SystemInfoService.cpuPerc, Theme.activeColor)
              size: "xs"
              text: qsTr("CPU %1%").arg((SystemInfoService.cpuPerc * 100).toFixed(0))
            }
            OText {
              bold: true
              color: root.statusColor(SystemInfoService.memPerc, Theme.powerSaveColor)
              size: "xs"
              text: qsTr("RAM %1%").arg((SystemInfoService.memPerc * 100).toFixed(0))
            }
            OText {
              bold: true
              color: root.statusColor(SystemInfoService.gpuPerc, Theme.warning)
              size: "xs"
              text: SystemInfoService.gpuType === "NONE" ? qsTr("GPU —") : qsTr("GPU %1%").arg((SystemInfoService.gpuPerc * 100).toFixed(0))
            }
            OText {
              bold: true
              color: root.statusColor(root.storageProgress, Theme.activeColor)
              size: "xs"
              text: qsTr("DISK %1%").arg((root.storageProgress * 100).toFixed(0))
            }
          }
        }
        OText {
          color: expandButton.textColor
          text: root.expanded ? "󰅀" : "󰅂"
        }
      }
    }
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: root.expanded ? details.implicitHeight : 0
      clip: true

      Behavior on Layout.preferredHeight {
        NumberAnimation {
          duration: Theme.animationSlow
          easing.type: Easing.OutCubic
        }
      }

      ColumnLayout {
        id: details

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.spacingSm

        GridLayout {
          Layout.fillWidth: true
          columnSpacing: Theme.spacingSm
          columns: 2
          rowSpacing: Theme.spacingSm

          MetricTile {
            accentColor: Theme.activeColor
            icon: "󰍛"
            label: qsTr("CPU")
            progress: SystemInfoService.cpuPerc
            secondary: SystemInfoService.cpuTemp > 0 ? `${SystemInfoService.cpuTemp.toFixed(0)}°C` : qsTr("No temperature")
            value: `${(SystemInfoService.cpuPerc * 100).toFixed(0)}%`
          }
          MetricTile {
            accentColor: Theme.powerSaveColor
            icon: "󰘚"
            label: qsTr("Memory")
            progress: SystemInfoService.memPerc
            secondary: `${Utils.fmtKib(SystemInfoService.memUsed)} / ${Utils.fmtKib(SystemInfoService.memTotal)}`
            value: `${(SystemInfoService.memPerc * 100).toFixed(0)}%`
          }
          GpuTile {
            Layout.columnSpan: 2
          }
          Repeater {
            model: SystemInfoService.storageDisks

            DiskTile {
              id: diskDelegate

              required property var modelData

              Layout.columnSpan: 2
              disk: diskDelegate.modelData
            }
          }
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: Theme.spacingSm

          OText {
            color: Theme.textInactiveColor
            size: "sm"
            text: qsTr("Uptime %1").arg(root.formatDuration(SystemInfoService.uptime))
          }
          Item {
            Layout.fillWidth: true
          }
          OText {
            color: Theme.textInactiveColor
            size: "sm"
            text: SystemInfoService.bootDuration ? qsTr("Boot %1").arg(SystemInfoService.bootDuration) : ""
            visible: text !== ""
          }
        }
      }
    }
  }

  component DiskTile: Rectangle {
    id: diskTile

    required property var disk

    Layout.fillWidth: true
    Layout.preferredHeight: diskLayout.implicitHeight + Theme.spacingSm * 2
    border.color: Qt.alpha(Theme.activeColor, 0.18)
    border.width: Theme.borderWidthThin
    color: Theme.bgCard
    radius: Theme.radiusMd

    ColumnLayout {
      id: diskLayout

      anchors.left: parent.left
      anchors.leftMargin: Theme.spacingSm
      anchors.right: parent.right
      anchors.rightMargin: Theme.spacingSm
      anchors.verticalCenter: parent.verticalCenter
      spacing: Theme.spacingSm

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingXs

        OText {
          color: Theme.activeColor
          text: "󰋊"
        }
        OText {
          Layout.fillWidth: true
          bold: true
          text: diskTile.disk.name
        }
        OText {
          color: Theme.textInactiveColor
          size: "sm"
          text: `${Utils.fmtKib(diskTile.disk.usedKib)} / ${Utils.fmtKib(diskTile.disk.totalKib)}`
        }
      }
      Repeater {
        model: diskTile.disk.partitions

        ColumnLayout {
          id: partitionDelegate

          required property var modelData

          Layout.fillWidth: true
          spacing: Theme.spacingXs

          RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            OText {
              Layout.fillWidth: true
              bold: true
              elide: Text.ElideMiddle
              size: "sm"
              text: partitionDelegate.modelData.mountPoint === "/" ? qsTr("Root") : partitionDelegate.modelData.mountPoint
            }
            OText {
              color: Theme.textInactiveColor
              size: "xs"
              text: `${Utils.fmtKib(partitionDelegate.modelData.usedKib)} / ${Utils.fmtKib(partitionDelegate.modelData.totalKib)}`
            }
            OText {
              bold: true
              color: root.statusColor(partitionDelegate.modelData.percentage, Theme.textActiveColor)
              size: "sm"
              text: `${(partitionDelegate.modelData.percentage * 100).toFixed(0)}%`
            }
          }
          ProgressTrack {
            accentColor: Theme.activeColor
            progress: partitionDelegate.modelData.percentage
          }
        }
      }
    }
  }
  component GpuTile: Rectangle {
    id: gpuTile

    readonly property real memoryProgress: SystemInfoService.gpuMemTotalKib > 0 ? SystemInfoService.gpuMemUsedKib / SystemInfoService.gpuMemTotalKib : 0

    Layout.fillWidth: true
    Layout.preferredHeight: gpuLayout.implicitHeight + Theme.spacingSm * 2
    border.color: Qt.alpha(Theme.warning, 0.22)
    border.width: Theme.borderWidthThin
    color: Theme.bgCard
    radius: Theme.radiusMd

    ColumnLayout {
      id: gpuLayout

      anchors.fill: parent
      anchors.margins: Theme.spacingSm
      spacing: Theme.spacingXs

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingXs

        OText {
          color: Theme.warning
          text: "󰢮"
        }
        OText {
          Layout.fillWidth: true
          bold: true
          elide: Text.ElideRight
          size: "sm"
          text: SystemInfoService.gpuType === "NONE" ? qsTr("GPU") : qsTr("GPU · %1").arg(SystemInfoService.gpuType)
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        OText {
          Layout.preferredWidth: Theme.itemWidth * 1.4
          size: "xs"
          text: qsTr("Usage")
        }
        ProgressTrack {
          accentColor: Theme.warning
          progress: SystemInfoService.gpuPerc
        }
        OText {
          Layout.preferredWidth: Theme.itemWidth
          bold: true
          color: root.statusColor(SystemInfoService.gpuPerc, Theme.warning)
          horizontalAlignment: Text.AlignRight
          size: "sm"
          text: SystemInfoService.gpuType === "NONE" ? "—" : `${(SystemInfoService.gpuPerc * 100).toFixed(0)}%`
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        visible: SystemInfoService.gpuMemTotalKib > 0

        OText {
          Layout.preferredWidth: Theme.itemWidth * 1.4
          size: "xs"
          text: qsTr("VRAM")
        }
        ProgressTrack {
          accentColor: Theme.onHoverColor
          progress: gpuTile.memoryProgress
        }
        OText {
          bold: true
          color: root.statusColor(gpuTile.memoryProgress, Theme.onHoverColor)
          horizontalAlignment: Text.AlignRight
          size: "sm"
          text: SystemInfoService.gpuMemTotalKib > 0 ? `${Utils.fmtKib(SystemInfoService.gpuMemUsedKib)} · ${(gpuTile.memoryProgress * 100).toFixed(0)}%` : "—"
        }
      }
      OText {
        color: SystemInfoService.gpuTemp >= 85 ? Theme.critical : SystemInfoService.gpuTemp >= 70 ? Theme.warning : Theme.textInactiveColor
        size: "xs"
        text: qsTr("Temperature %1°C").arg(SystemInfoService.gpuTemp.toFixed(0))
        visible: SystemInfoService.gpuTemp > 0
      }
    }
  }
  component MetricTile: Rectangle {
    id: tile

    required property color accentColor
    required property string icon
    required property string label
    required property real progress
    required property string secondary
    required property string value

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.itemHeight * 2.2
    border.color: Qt.alpha(tile.accentColor, 0.22)
    border.width: Theme.borderWidthThin
    color: Theme.bgCard
    radius: Theme.radiusMd

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Theme.spacingSm
      spacing: Theme.spacingXs

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingXs

        OText {
          color: tile.accentColor
          text: tile.icon
        }
        OText {
          Layout.fillWidth: true
          bold: true
          elide: Text.ElideRight
          size: "sm"
          text: tile.label
        }
        OText {
          bold: true
          color: root.statusColor(tile.progress, tile.accentColor)
          text: tile.value
        }
      }
      ProgressTrack {
        accentColor: tile.accentColor
        progress: tile.progress
      }
      OText {
        Layout.fillWidth: true
        color: Theme.textInactiveColor
        elide: Text.ElideRight
        size: "xs"
        text: tile.secondary
      }
    }
  }
  component ProgressTrack: Rectangle {
    id: track

    required property color accentColor
    required property real progress

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.spacingXs
    color: Theme.borderSubtle
    radius: height / 2

    FillBar {
      fillColor: root.statusColor(track.progress, track.accentColor)
      progress: track.progress
      radius: track.radius
    }
  }
}
