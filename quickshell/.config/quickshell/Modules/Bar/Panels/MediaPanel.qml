pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Components
import qs.Config
import qs.Services.Core
import qs.Services.Utils

PanelContentBase {
  id: root

  readonly property var activePlayer: MediaService.active
  // Every read of position costs a DBus round trip, so never ask for one the seek bar cannot use.
  readonly property bool canTrackPosition: (root.activePlayer?.positionSupported ?? false) && MediaService.trackLength > 0
  readonly property bool hasPlayer: !!root.activePlayer
  readonly property real positionRatio: MediaService.trackLength > 0 ? trackPosition / MediaService.trackLength : 0
  readonly property real trackPosition: {
    const position = activePlayer?.position ?? 0;
    const safePosition = Number.isFinite(position) && position >= 0 ? position : 0;
    return MediaService.trackLength > 0 ? Math.min(safePosition, MediaService.trackLength) : safePosition;
  }

  function formatTime(seconds: real): string {
    const wholeSeconds = Math.max(0, Math.floor(seconds));
    const minutes = Math.floor(wholeSeconds / 60);
    return `${minutes}:${String(wholeSeconds % 60).padStart(2, "0")}`;
  }

  flatContainer: true
  preferredHeight: contentLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: Theme.mediaPanelWidth

  onIsOpenChanged: if (isOpen) {
    seekSlider.value = positionRatio;
    if (root.canTrackPosition)
      activePlayer.positionChanged();
  }
  onPositionRatioChanged: if (!seekSlider.dragging)
    seekSlider.value = positionRatio

  Timer {
    interval: 500
    repeat: true
    running: root.isOpen && MediaService.playing && root.canTrackPosition

    onTriggered: root.activePlayer.positionChanged()
  }
  ColumnLayout {
    id: contentLayout

    anchors.left: parent.left
    anchors.margins: Theme.spacingMd
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Theme.spacingMd

    PanelHeader {
      icon: "󰎆"
      subtitle: root.activePlayer?.identity ?? qsTr("No media player running")
      title: qsTr("Media")

      PanelActionIcon {
        icon: "󰲰"
        tooltipText: qsTr("Switch player (%1 available)").arg(MediaService.players.length)
        visible: MediaService.players.length > 1

        onClicked: MediaService.selectNextPlayer()
      }
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingMd
      visible: root.hasPlayer

      ClippingRectangle {
        Layout.alignment: Qt.AlignTop
        Layout.preferredHeight: Theme.mediaArtworkSize
        Layout.preferredWidth: Theme.mediaArtworkSize
        color: Theme.glassControlColor
        radius: Theme.radiusMd

        Image {
          id: fallbackImage

          anchors.fill: parent
          anchors.margins: Theme.spacingLg
          asynchronous: true
          fillMode: Image.PreserveAspectFit
          source: Utils.resolveIconSource(root.activePlayer?.desktopEntry ?? "", "", "multimedia-player")
          sourceSize: Qt.size(width, height)
          visible: artwork.status !== Image.Ready
        }
        OText {
          anchors.centerIn: parent
          font.family: Theme.iconFontFamily
          font.pixelSize: Theme.iconSizeXl
          text: "󰎆"
          visible: artwork.status !== Image.Ready && fallbackImage.status !== Image.Ready
        }
        Image {
          id: artwork

          anchors.fill: parent
          asynchronous: true
          fillMode: Image.PreserveAspectCrop
          source: Utils.normalizeImageUrl(MediaService.trackArtUrl)
          sourceSize: Qt.size(width, height)
          visible: status === Image.Ready
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingXs

        OText {
          Layout.fillWidth: true
          bold: true
          size: "lg"
          text: root.activePlayer?.trackTitle || root.activePlayer?.identity || qsTr("Unknown track")
        }
        OText {
          Layout.fillWidth: true
          color: Theme.textInactiveColor
          size: "sm"
          text: root.activePlayer?.trackArtist || root.activePlayer?.trackAlbum || root.activePlayer?.identity || qsTr("Unknown artist")
        }
        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: Theme.spacingSm

          PanelActionIcon {
            icon: "󰒮"
            isEnabled: MediaService.canGoPrevious
            tooltipText: qsTr("Previous")

            onClicked: MediaService.previous()
          }
          PanelActionIcon {
            icon: "󱇹"
            isEnabled: MediaService.canSeek
            tooltipText: qsTr("Back 5 seconds")

            onClicked: MediaService.seekBy(-5)
          }
          PanelActionIcon {
            icon: MediaService.playing ? "󰏤" : "󰐊"
            isEnabled: MediaService.canTogglePlaying
            size: "md"
            tooltipText: MediaService.playing ? qsTr("Pause") : qsTr("Play")

            onClicked: MediaService.playPause()
          }
          PanelActionIcon {
            icon: "󰓛"
            isEnabled: root.activePlayer?.canControl ?? false
            tooltipText: qsTr("Stop")

            onClicked: MediaService.stop()
          }
          PanelActionIcon {
            icon: "󱇸"
            isEnabled: MediaService.canSeek
            tooltipText: qsTr("Forward 5 seconds")

            onClicked: MediaService.seekBy(5)
          }
          PanelActionIcon {
            icon: "󰒭"
            isEnabled: MediaService.canGoNext
            tooltipText: qsTr("Next")

            onClicked: MediaService.next()
          }
        }
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Theme.spacingMd
          color: Theme.glassControlColor
          radius: Theme.radiusSm

          Slider {
            id: seekSlider

            anchors.fill: parent
            animMs: 0
            interactive: MediaService.canSeek && root.canTrackPosition
            radius: parent.radius

            onCommitted: ratio => MediaService.seekByRatio(ratio)
          }
        }
        RowLayout {
          Layout.fillWidth: true

          OText {
            Layout.fillWidth: true
            color: Theme.textInactiveColor
            size: "xs"
            text: root.formatTime(seekSlider.dragging ? seekSlider.pending * MediaService.trackLength : root.trackPosition)
          }
          OText {
            color: Theme.textInactiveColor
            size: "xs"
            text: root.formatTime(MediaService.trackLength)
          }
        }
      }
    }
    PanelEmptyState {
      Layout.fillWidth: true
      Layout.preferredHeight: Theme.mediaArtworkSize
      icon: "󰎆"
      text: qsTr("Nothing playing")
      visible: !root.hasPlayer
    }
  }
  HoverHandler {
    onHoveredChanged: if (root.panelData)
      root.panelData.panelHovered = hovered
  }
}
