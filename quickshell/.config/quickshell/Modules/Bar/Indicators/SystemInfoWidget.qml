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
  property string expandedDiskKey: ""
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
  onExpandedChanged: if (!expanded)
    expandedDiskKey = ""
  onActiveChanged: {
    syncPolling();
    if (!active)
      expandedDiskKey = "";
  }

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

  component DiskTile: PanelRow {
    id: diskTile

    required property var disk
    readonly property string diskKey: disk.name ?? ""

    Layout.fillWidth: true
    expanded: root.expandedDiskKey === diskKey
    icon: "󰋊"
    rowActionEnabled: (disk.partitions?.length ?? 0) > 0
    subtitle: `${Utils.fmtKib(disk.usedKib)} / ${Utils.fmtKib(disk.totalKib)}`
    title: disk.name
    onClicked: root.expandedDiskKey = expanded ? "" : diskKey
    badges: [OText { color: Theme.activeColor; text: diskTile.expanded ? "󰅀" : "󰅂" }]
    expandedContent: [
      ColumnLayout {
        width: parent?.width ?? 0
        spacing: Theme.spacingXs

      Repeater {
        model: diskTile.disk.partitions

        PanelRow {
          id: partitionDelegate

          required property var modelData

          width: parent?.width ?? 0
          rowActionEnabled: false
          subtitle: `${Utils.fmtKib(modelData.usedKib)} / ${Utils.fmtKib(modelData.totalKib)}`
          title: modelData.mountPoint === "/" ? qsTr("Root") : modelData.mountPoint
          badges: [OText { bold: true; color: root.statusColor(partitionDelegate.modelData.percentage, Theme.textActiveColor); size: "sm"; text: `${(partitionDelegate.modelData.percentage * 100).toFixed(0)}%` }]
        }
      }
      }
    ]
  }
  component GpuTile: PanelCard {
    id: gpuTile

    readonly property real memoryProgress: SystemInfoService.gpuMemTotalKib > 0 ? SystemInfoService.gpuMemUsedKib / SystemInfoService.gpuMemTotalKib : 0

    Layout.fillWidth: true
    Layout.preferredHeight: gpuLayout.implicitHeight + Theme.spacingSm * 2
    padding: 0

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
  component MetricTile: PanelCard {
    id: tile

    required property color accentColor
    required property string icon
    required property string label
    required property real progress
    required property string secondary
    required property string value

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.itemHeight * 2.2
    padding: 0

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
