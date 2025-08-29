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

  height: implicitHeight
  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemHeight
  width: implicitWidth

  Keys.onReleased: event => {
    if (!focusable || disabled || busy)
      return;
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      root.clicked(null);
      root.leftClicked();
      event.accepted = true;
    }
  }

  Rectangle {
    id: bgRect

    anchors.fill: parent
    antialiasing: true
    color: root.effectiveBg
    radius: Math.min(width, height) / 2

    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.InOutQuad
      }
    }

    MouseArea {
      id: mouseArea

      acceptedButtons: Qt.LeftButton | Qt.RightButton
      anchors.fill: parent
      cursorShape: (root.busy ? Qt.BusyCursor : (root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor))
      hoverEnabled: true

      onClicked: function (mouse) {
        if (root.busy || root.disabled)
          return;
        root.clicked(mouse);
        if (mouse.button === Qt.LeftButton)
          root.leftClicked();
        else if (mouse.button === Qt.RightButton)
          root.rightClicked();
      }
      onEntered: {
        if (!root.disabled)
          root.hovered = true;
        root.entered();
      }
      onExited: {
        root.hovered = false;
        root.exited();
      }
      onPressed: function (mouse) {
        if (root.busy || root.disabled)
          return;
        root.pressed(mouse);
      }
      onReleased: function (mouse) {
        if (root.busy || root.disabled)
          return;
        root.released(mouse);
      }
    }
    Item {
      anchors.fill: parent

      Loader {
        id: contentLoader

        anchors.centerIn: parent
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
