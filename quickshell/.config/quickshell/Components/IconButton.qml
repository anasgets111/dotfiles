pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import qs.Config

Item {
  id: root

  property alias area: mouseArea
  property color bgColor: Theme.inactiveColor
  property bool busy: false
  property alias contentItem: contentLoader.sourceComponent
  property bool contentFills: false
  property bool disabled: false
  property color disabledBgColor: Theme.inactiveColor
  readonly property color effectiveBg: disabled ? disabledBgColor : (hovered && !busy ? hoverBgColor : bgColor)
  readonly property color fgColor: Theme.textContrast(effectiveBg)
  property bool focusable: false
  property color hoverBgColor: Theme.onHoverColor
  property bool hovered: false
  property font iconFont: Qt.font({
    family: Theme.fontFamily,
    pixelSize: Theme.fontSize,
    bold: true
  })
  property string iconText: ""

  // Signals
  signal clicked(var mouse)
  signal entered
  signal exited
  signal leftClicked
  signal pressed(var mouse)
  signal released(var mouse)
  signal rightClicked
  signal middleClicked

  height: implicitHeight
  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemHeight
  width: implicitWidth

  Rectangle {
    id: bgRect

    anchors.fill: parent
    antialiasing: true
    color: mouseArea.containsPress ? root.hoverBgColor : root.effectiveBg
    radius: Math.min(width, height) / 2

    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.InOutQuad
      }
    }

    MouseArea {
      id: mouseArea

      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      anchors.fill: parent
      cursorShape: (root.busy ? Qt.BusyCursor : (root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor))
      hoverEnabled: true
      enabled: !root.disabled && !root.busy

      onClicked: function (mouse) {
        root.clicked(mouse);
        if (mouse.button === Qt.LeftButton)
          root.leftClicked();
        else if (mouse.button === Qt.RightButton)
          root.rightClicked();
        else if (mouse.button === Qt.MiddleButton)
          root.middleClicked();
      }
      onEntered: {
        root.hovered = true;
        root.entered();
      }
      onExited: {
        root.hovered = false;
        root.exited();
      }
      onPressed: function (mouse) {
        root.pressed(mouse);
      }
      onReleased: function (mouse) {
        root.released(mouse);
      }
    }
    Item {
      anchors.fill: parent

      Loader {
        id: contentLoader
        anchors.fill: root.contentFills ? parent : undefined
        anchors.centerIn: root.contentFills ? undefined : parent
      }
      Text {
        anchors.centerIn: parent
        color: root.fgColor
        elide: Text.ElideNone
        font: root.iconFont
        horizontalAlignment: Text.AlignHCenter
        text: root.iconText
        verticalAlignment: Text.AlignVCenter
        visible: contentLoader.status !== Loader.Ready && root.iconText.length > 0
      }
    }
  }
}
