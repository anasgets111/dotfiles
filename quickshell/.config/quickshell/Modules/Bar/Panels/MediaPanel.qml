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
  readonly property real positionRatio: MediaService.trackLength > 0 ? trackPosition / MediaService.trackLength : 0
  readonly property real trackPosition: {
    const position = activePlayer?.position ?? 0;
    const safePosition = Number.isFinite(position) && position >= 0 ? position : 0;
    return MediaService.trackLength > 0 ? Math.min(safePosition, MediaService.trackLength) : safePosition;
  }

  flatContainer: true
  preferredHeight: Math.max(Theme.mediaArtworkSize, details.implicitHeight) + Theme.spacingMd * 2
  preferredWidth: Theme.mediaPanelWidth

  function formatTime(seconds: real): string {
    const wholeSeconds = Math.max(0, Math.floor(seconds));
    const minutes = Math.floor(wholeSeconds / 60);
    return `${minutes}:${String(wholeSeconds % 60).padStart(2, "0")}`;
  }

  onIsOpenChanged: if (isOpen) {
    seekSlider.value = positionRatio;
    activePlayer?.positionChanged();
  }
  onPositionRatioChanged: if (!seekSlider.dragging)
    seekSlider.value = positionRatio

  Timer {
    interval: 500
    repeat: true
    running: root.isOpen && MediaService.playing

    onTriggered: root.activePlayer?.positionChanged()
  }
  RowLayout {
    anchors.fill: parent
    anchors.margins: Theme.spacingMd
    spacing: Theme.spacingMd

    ClippingRectangle {
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
        source: Utils.normalizeImageUrl(root.activePlayer?.trackArtUrl ?? "")
        sourceSize: Qt.size(width, height)
        visible: status === Image.Ready
      }
    }
    ColumnLayout {
      id: details

      Layout.fillHeight: true
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
          icon: MediaService.playing ? "󰏤" : "󰐊"
          isEnabled: MediaService.canTogglePlaying
          size: "md"
          tooltipText: MediaService.playing ? qsTr("Pause") : qsTr("Play")

          onClicked: MediaService.playPause()
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
        Layout.preferredHeight: Theme.spacingSm
        color: Theme.glassControlColor
        radius: Theme.radiusSm

        Slider {
          id: seekSlider

          anchors.fill: parent
          animMs: 0
          interactive: MediaService.canSeek && root.activePlayer?.positionSupported && MediaService.trackLength > 0
          radius: parent.radius

          onCommitted: ratio => MediaService.seekByRatio(ratio)
        }
      }
      RowLayout {
        Layout.fillWidth: true

        OText {
          color: Theme.textInactiveColor
          size: "xs"
          text: root.formatTime(seekSlider.dragging ? seekSlider.pending * MediaService.trackLength : root.trackPosition)
        }
        Item {
          Layout.fillWidth: true
        }
        OText {
          color: Theme.textInactiveColor
          size: "xs"
          text: root.formatTime(MediaService.trackLength)
        }
      }
    }
  }
  HoverHandler {
    onHoveredChanged: root.panelData?.setPanelHovered(hovered)
  }
}
