pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.Config

PanelContentBase {
  id: root

  readonly property var menuItem: panelData?.menuItem ?? null

  preferredHeight: menuContent.implicitHeight + Theme.spacingSm * 2
  preferredWidth: 300

  QsMenuOpener {
    id: menuOpener

    menu: root.menuItem?.menu ?? null
  }

  Component {
    id: menuRowComponent

    Item {
      id: rowItem

      property QsMenuEntry entry: null
      readonly property string iconSource: entry?.icon ?? ""

      anchors.fill: parent

      Rectangle {
        anchors.centerIn: parent
        color: Theme.borderColor
        height: 1
        visible: rowItem.entry?.isSeparator ?? false
        width: parent.width - Theme.spacingSm
      }

      Rectangle {
        anchors.fill: parent
        color: rowMouse.containsMouse ? Theme.onHoverColor : "transparent"
        radius: Theme.itemRadius
        visible: !(rowItem.entry?.isSeparator ?? false)

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Theme.spacingSm
          anchors.rightMargin: Theme.spacingSm
          spacing: Theme.spacingSm

          Image {
            Layout.preferredHeight: Theme.iconSizeSm
            Layout.preferredWidth: Theme.iconSizeSm
            fillMode: Image.PreserveAspectFit
            source: rowItem.iconSource
            sourceSize: Qt.size(Theme.iconSizeSm, Theme.iconSizeSm)
            visible: rowItem.iconSource !== ""
          }

          OText {
            Layout.fillWidth: true
            color: rowMouse.containsMouse ? Theme.textContrast(Theme.onHoverColor) : Theme.textActiveColor
            elide: Text.ElideRight
            opacity: rowItem.entry?.enabled ? 1.0 : 0.5
            text: rowItem.entry?.text ?? ""
            verticalAlignment: Text.AlignVCenter
          }

          OText {
            color: rowMouse.containsMouse ? Theme.textContrast(Theme.onHoverColor) : Theme.textActiveColor
            text: rowItem.entry?.hasChildren ? "›" : rowItem.entry?.buttonType === QsMenuButtonType.CheckBox && rowItem.entry?.checkState === Qt.Checked ? "✓" : rowItem.entry?.buttonType === QsMenuButtonType.RadioButton && rowItem.entry?.checkState === Qt.Checked ? "●" : ""
          }
        }

        MouseArea {
          id: rowMouse

          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          enabled: rowItem.entry?.enabled ?? true
          hoverEnabled: true

          onClicked: if (!rowItem.entry?.hasChildren) {
            rowItem.entry?.triggered();
            root.closeRequested();
          }
          onEntered: {
            subTimer.stop();
            if (rowItem.entry?.hasChildren)
              subLoader.active = true;
          }
          onExited: subTimer.start()
        }
      }

      Loader {
        id: subLoader

        active: false
        sourceComponent: submenuPopupComponent

        onLoaded: {
          item["submenuHandle"] = rowItem.entry;
          item["anchorTo"] = rowItem;
          item["enterCallback"] = () => subTimer.stop();
          item.visible = true;
        }
      }

      Timer {
        id: subTimer

        interval: 450

        onTriggered: if (!rowMouse.containsMouse)
          subLoader.active = false
      }

      Connections {
        function onIsOpenChanged() {
          if (!root.isOpen)
            subLoader.active = false;
        }

        target: root
      }
    }
  }

  Component {
    id: submenuPopupComponent

    PopupWindow {
      id: subPopup

      property Item anchorTo: null
      property var enterCallback: null
      property QsMenuHandle submenuHandle: null

      anchor.item: anchorTo
      anchor.rect.x: (anchorTo?.width ?? 0) + Theme.spacingSm
      color: "transparent"
      implicitHeight: subLayout.implicitHeight + Theme.spacingSm * 2
      implicitWidth: root.preferredWidth

      QsMenuOpener {
        id: subOpener

        menu: subPopup.submenuHandle
      }

      Rectangle {
        anchors.fill: parent
        border.color: Theme.borderColor
        border.width: Theme.borderWidthThin
        bottomLeftRadius: Theme.itemRadius
        bottomRightRadius: Theme.itemRadius
        color: Theme.bgColor

        ColumnLayout {
          id: subLayout

          anchors.fill: parent
          anchors.margins: Theme.spacingSm
          spacing: Theme.spacingXs / 2

          Repeater {
            model: subOpener.children

            delegate: Loader {
              id: submenuRowLoader

              required property QsMenuEntry modelData

              Layout.fillWidth: true
              Layout.preferredHeight: submenuRowLoader.modelData?.isSeparator ? 8 : Theme.itemHeight
              sourceComponent: menuRowComponent

              onLoaded: item["entry"] = submenuRowLoader.modelData
            }
          }
        }
      }

      HoverHandler {
        onHoveredChanged: if (hovered)
          subPopup.enterCallback?.()
      }
    }
  }

  ColumnLayout {
    id: menuContent

    anchors.fill: parent
    anchors.margins: Theme.spacingSm
    spacing: Theme.spacingXs / 2

    Repeater {
      id: menuRepeater

      model: menuOpener.children ?? []

      delegate: Loader {
        id: menuRowLoader

        required property QsMenuEntry modelData

        Layout.fillWidth: true
        Layout.preferredHeight: menuRowLoader.modelData?.isSeparator ? 8 : Theme.itemHeight
        sourceComponent: menuRowComponent

        onLoaded: item["entry"] = menuRowLoader.modelData
      }
    }

    OText {
      Layout.fillWidth: true
      Layout.preferredHeight: Theme.itemHeight
      color: Theme.textActiveColor
      horizontalAlignment: Text.AlignHCenter
      text: "No menu items"
      verticalAlignment: Text.AlignVCenter
      visible: menuRepeater.count === 0
    }
  }
}
