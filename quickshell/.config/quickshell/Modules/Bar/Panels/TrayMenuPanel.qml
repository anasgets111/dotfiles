import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.Config

PanelContentBase {
  id: root

  readonly property var menuItem: panelData?.menuItem ?? null
  readonly property real preferredHeight: menuContent.implicitHeight + Theme.spacingSm * 2
  readonly property real preferredWidth: 300

  QsMenuOpener {
    id: menuOpener

    menu: root.menuItem?.menu ?? null
  }

  Component {
    id: menuRowComponent

    Item {
      id: rowItem

      anchors.fill: parent

      Rectangle {
        anchors.centerIn: parent
        color: Theme.borderColor
        height: 1
        visible: modelData?.isSeparator ?? false
        width: parent.width - Theme.spacingSm
      }

      Rectangle {
        anchors.fill: parent
        color: rowMouse.containsMouse ? Theme.onHoverColor : "transparent"
        radius: Theme.itemRadius
        visible: !(modelData?.isSeparator ?? false)

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Theme.spacingSm
          anchors.rightMargin: Theme.spacingSm
          spacing: Theme.spacingSm

          Image {
            Layout.preferredHeight: Theme.iconSizeSm
            Layout.preferredWidth: Theme.iconSizeSm
            fillMode: Image.PreserveAspectFit
            source: modelData?.icon ?? ""
            sourceSize: Qt.size(Theme.iconSizeSm, Theme.iconSizeSm)
            visible: (modelData?.icon ?? "") !== ""
          }

          OText {
            Layout.fillWidth: true
            color: rowMouse.containsMouse ? Theme.textContrast(Theme.onHoverColor) : Theme.textActiveColor
            elide: Text.ElideRight
            opacity: modelData?.enabled ? 1.0 : 0.5
            text: modelData?.text ?? ""
            verticalAlignment: Text.AlignVCenter
          }

          OText {
            color: rowMouse.containsMouse ? Theme.textContrast(Theme.onHoverColor) : Theme.textActiveColor
            text: modelData?.hasChildren ? "›" : modelData?.buttonType === QsMenuButtonType.CheckBox && modelData?.checkState === Qt.Checked ? "✓" : modelData?.buttonType === QsMenuButtonType.RadioButton && modelData?.checkState === Qt.Checked ? "●" : ""
          }
        }

        MouseArea {
          id: rowMouse

          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          enabled: modelData?.enabled ?? true
          hoverEnabled: true

          onClicked: if (!modelData?.hasChildren) {
            modelData?.triggered();
            root.closeRequested();
          }
          onEntered: {
            subTimer.stop();
            if (modelData?.hasChildren)
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
          item.submenuHandle = modelData;
          item.anchorTo = rowItem;
          item.entered.connect(() => subTimer.stop());
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
      property QsMenuHandle submenuHandle: null

      signal entered

      anchor.edges: Edges.Top | Edges.Left
      anchor.gravity: Edges.Bottom | Edges.Right
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
              required property QsMenuEntry modelData

              Layout.fillWidth: true
              Layout.preferredHeight: modelData?.isSeparator ? 8 : Theme.itemHeight
              sourceComponent: menuRowComponent
            }
          }
        }
      }

      HoverHandler {
        onHoveredChanged: if (hovered)
          subPopup.entered()
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
        required property QsMenuEntry modelData

        Layout.fillWidth: true
        Layout.preferredHeight: modelData?.isSeparator ? 8 : Theme.itemHeight
        sourceComponent: menuRowComponent
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
