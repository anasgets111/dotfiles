pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Components
import qs.Services.WM

SearchGridPanel {
  id: picker

  signal applyRequested
  signal cancelRequested

  property alias folderInput: folderPathInput
  property alias browseButton: folderBrowseButton
  property alias monitorCombo: monitorSelector
  property alias fillModeCombo: fillModeSelector
  property alias transitionCombo: transitionSelector
  property alias applyButton: applyActionButton
  property alias cancelButton: cancelActionButton

  property var monitorOptions: defaultMonitorOptions
  property var fillModeOptions: [
    {
      label: qsTr("Fill"),
      value: "fill"
    },
    {
      label: qsTr("Fit"),
      value: "fit"
    },
    {
      label: qsTr("Center"),
      value: "center"
    },
    {
      label: qsTr("Stretch"),
      value: "stretch"
    },
    {
      label: qsTr("Tile"),
      value: "tile"
    }
  ]
  property var transitionOptions: [
    {
      label: qsTr("Fade"),
      value: "fade"
    },
    {
      label: qsTr("Wipe"),
      value: "wipe"
    },
    {
      label: qsTr("Disc"),
      value: "disc"
    },
    {
      label: qsTr("Stripes"),
      value: "stripes"
    },
    {
      label: qsTr("Portal"),
      value: "portal"
    }
  ]

  readonly property var defaultMonitorOptions: [
    {
      label: qsTr("All Monitors"),
      value: "all"
    }
  ]

  windowWidth: 900
  windowHeight: 520
  itemImageSize: 265
  contentMargin: 16
  contentSpacing: 10
  closeOnActivate: false
  placeholderText: qsTr("Search wallpapers…")

  headerContent: [
    RowLayout {
      Layout.fillWidth: true
      spacing: 16

      RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 280
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        spacing: 8

        TextField {
          id: folderPathInput
          Layout.fillWidth: true
          placeholderText: qsTr("Wallpaper folder path")
        }

        Button {
          id: folderBrowseButton
          text: qsTr("Browse…")
        }
      }

      RowLayout {
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        spacing: 8

        ComboBox {
          id: monitorSelector
          Layout.preferredWidth: 200
          model: picker.monitorOptions
          textRole: "label"
          valueRole: "value"
        }
      }

      RowLayout {
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        spacing: 8

        ComboBox {
          id: fillModeSelector
          Layout.preferredWidth: 140
          model: picker.fillModeOptions
          textRole: "label"
          valueRole: "value"
        }

        ComboBox {
          id: transitionSelector
          Layout.preferredWidth: 150
          model: picker.transitionOptions
          textRole: "label"
          valueRole: "value"
        }
      }
    }
  ]

  footerContent: [
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Button {
        id: cancelActionButton
        text: qsTr("Cancel")
        onClicked: picker.cancelRequested()
      }

      Item {
        Layout.fillWidth: true
      }

      Button {
        id: applyActionButton
        text: qsTr("Apply")
        highlighted: true
        onClicked: picker.applyRequested()
      }
    }
  ]
}
